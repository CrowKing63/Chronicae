using Chronicae.Server.Windows.Data;
using Chronicae.Server.Windows.Models;
using Chronicae.Server.Windows.Services;
using Microsoft.AspNetCore.Mvc; // Added for [FromQuery]
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddDbContext<ChronicaeDbContext>(options => options.UseSqlite("Data Source=chronicae.db"));
builder.Services.AddSingleton<SseService>();
// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

#region Status Endpoints
app.MapGet("/api/status", (ChronicaeDbContext db) =>
{
    //TODO: get real data from db
    var status = new SystemStatus(1234, "default-project-id", 5, 512, 1337);
    return status;
})
.WithName("GetStatus")
.WithOpenApi();
#endregion

#region SSE Endpoints
app.MapGet("/api/events", async (HttpContext context, SseService sseService) =>
{
    context.Response.Headers.Append("Content-Type", "text/event-stream");
    context.Response.Headers.Append("Cache-Control", "no-cache");
    context.Response.Headers.Append("Connection", "keep-alive");

    var streamWriter = new StreamWriter(context.Response.Body);
    sseService.AddClient(streamWriter);

    // Keep the connection open
            var tcs = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
    context.RequestAborted.Register(() => tcs.SetResult());
    await tcs.Task;

    sseService.RemoveClient(streamWriter);
});
#endregion

#region Project Endpoints
app.MapGet("/api/projects", async (ChronicaeDbContext db) =>
{
    return await db.Projects.ToListAsync();
})
.WithName("GetProjects")
.WithOpenApi();

app.MapGet("/api/projects/{id}", async (string id, ChronicaeDbContext db) =>
{
    return await db.Projects.FindAsync(id)
        is Project project
            ? Results.Ok(project)
            : Results.NotFound();
})
.WithName("GetProjectById")
.WithOpenApi();

app.MapPost("/api/projects", async (Project inputProject, ChronicaeDbContext db, SseService sseService) =>
{
    var project = new Project
    {
        Id = Guid.NewGuid().ToString(),
        Name = inputProject.Name,
        CreatedAt = DateTimeOffset.UtcNow,
        UpdatedAt = DateTimeOffset.UtcNow,
        NoteCount = 0,
        VectorStatus = new VectorStatus { LastIndexedAt = DateTimeOffset.MinValue, PendingJobs = 0 }
    };

    db.Projects.Add(project);
    await db.SaveChangesAsync();

    await sseService.BroadcastEvent(new SseEvent { Event = "project.created", Data = project });

    return Results.Created($"/api/projects/{project.Id}", project);
})
.WithName("CreateProject")
.WithOpenApi();

app.MapPut("/api/projects/{id}", async (string id, Project inputProject, ChronicaeDbContext db, SseService sseService) =>
{
    var project = await db.Projects.FindAsync(id);

    if (project is null) return Results.NotFound();

    project.Name = inputProject.Name;
    project.UpdatedAt = DateTimeOffset.UtcNow; // Update timestamp

    await db.SaveChangesAsync();

    await sseService.BroadcastEvent(new SseEvent { Event = "project.updated", Data = project });

    return Results.NoContent();
})
.WithName("UpdateProject")
.WithOpenApi();

app.MapDelete("/api/projects/{id}", async (string id, ChronicaeDbContext db, SseService sseService) =>
{
    if (await db.Projects.FindAsync(id) is Project project)
    {
        // Delete associated notes first
        var notesToDelete = await db.Notes.Where(n => n.ProjectId == id).ToListAsync();
        db.Notes.RemoveRange(notesToDelete);

        db.Projects.Remove(project);
        await db.SaveChangesAsync();

        await sseService.BroadcastEvent(new SseEvent { Event = "project.deleted", Data = new { id } });

        return Results.Ok(project);
    }

    return Results.NotFound();
})
.WithName("DeleteProject")
.WithOpenApi();
#endregion

#region Note Endpoints
app.MapGet("/api/projects/{projectId}/notes", async (string projectId, ChronicaeDbContext db) =>
{
    return await db.Notes.Where(n => n.ProjectId == projectId).ToListAsync();
})
.WithName("GetNotes")
.WithOpenApi();

app.MapGet("/api/projects/{projectId}/notes/{noteId}", async (string projectId, string noteId, ChronicaeDbContext db) =>
{
    return await db.Notes.FindAsync(noteId)
        is Note note && note.ProjectId == projectId
            ? Results.Ok(note)
            : Results.NotFound();
})
.WithName("GetNoteById")
.WithOpenApi();

app.MapPost("/api/projects/{projectId}/notes", async (string projectId, Note inputNote, ChronicaeDbContext db, SseService sseService) =>
{
    var note = new Note
    {
        Id = Guid.NewGuid().ToString(),
        ProjectId = projectId,
        Title = inputNote.Title,
        Tags = inputNote.Tags,
        CreatedAt = DateTimeOffset.UtcNow,
        UpdatedAt = DateTimeOffset.UtcNow,
        Excerpt = inputNote.Excerpt,
        Content = inputNote.Content, // Update Content
        Version = 1 // Initial version
    };

    db.Notes.Add(note);
    await db.SaveChangesAsync();

    await sseService.BroadcastEvent(new SseEvent { Event = "note.created", Data = note });

    return Results.Created($"/api/projects/{projectId}/notes/{note.Id}", note);
})
.WithName("CreateNote")
.WithOpenApi();

app.MapPut("/api/projects/{projectId}/notes/{noteId}", async (string projectId, string noteId, Note inputNote, ChronicaeDbContext db, SseService sseService) =>
{
    var note = await db.Notes.FindAsync(noteId);

    if (note is null || note.ProjectId != projectId) return Results.NotFound();

    note.Title = inputNote.Title;
    note.Tags = inputNote.Tags;
    note.Excerpt = inputNote.Excerpt;
    note.Content = inputNote.Content; // Update Content
    note.UpdatedAt = DateTimeOffset.UtcNow; // Update timestamp
    note.Version++; // Increment version

    await db.SaveChangesAsync();

    await sseService.BroadcastEvent(new SseEvent { Event = "note.updated", Data = note });

    return Results.NoContent();
})
.WithName("UpdateNote")
.WithOpenApi();

app.MapDelete("/api/projects/{projectId}/notes/{noteId}", async (string projectId, string noteId, ChronicaeDbContext db, SseService sseService, [FromQuery] bool purgeVersions = false) =>
{
    if (await db.Notes.FindAsync(noteId) is Note note && note.ProjectId == projectId)
    {
        db.Notes.Remove(note);
        await db.SaveChangesAsync();

        // TODO: Implement logic to purge versions if purgeVersions is true

        await sseService.BroadcastEvent(new SseEvent { Event = "note.deleted", Data = new { noteId, projectId } });

        return Results.Ok(note);
    }

    return Results.NotFound();
})
.WithName("DeleteNote")
.WithOpenApi();
#endregion

app.Run();