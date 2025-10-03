using Chronicae.Server.Windows.Data;
using Chronicae.Server.Windows.Models;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddDbContext<ChronicaeDbContext>(options => options.UseSqlite("Data Source=chronicae.db"));
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

app.MapPost("/api/projects", async (Project project, ChronicaeDbContext db) =>
{
    db.Projects.Add(project);
    await db.SaveChangesAsync();

    return Results.Created($"/api/projects/{project.Id}", project);
})
.WithName("CreateProject")
.WithOpenApi();

app.MapPut("/api/projects/{id}", async (string id, Project inputProject, ChronicaeDbContext db) =>
{
    var project = await db.Projects.FindAsync(id);

    if (project is null) return Results.NotFound();

    project.Name = inputProject.Name;
    // Other properties to update

    await db.SaveChangesAsync();

    return Results.NoContent();
})
.WithName("UpdateProject")
.WithOpenApi();

app.MapDelete("/api/projects/{id}", async (string id, ChronicaeDbContext db) =>
{
    if (await db.Projects.FindAsync(id) is Project project)
    {
        db.Projects.Remove(project);
        await db.SaveChangesAsync();
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

app.MapPost("/api/projects/{projectId}/notes", async (string projectId, Note note, ChronicaeDbContext db) =>
{
    note.ProjectId = projectId;
    db.Notes.Add(note);
    await db.SaveChangesAsync();

    return Results.Created($"/api/projects/{projectId}/notes/{note.Id}", note);
})
.WithName("CreateNote")
.WithOpenApi();

app.MapPut("/api/projects/{projectId}/notes/{noteId}", async (string projectId, string noteId, Note inputNote, ChronicaeDbContext db) =>
{
    var note = await db.Notes.FindAsync(noteId);

    if (note is null || note.ProjectId != projectId) return Results.NotFound();

    note.Title = inputNote.Title;
    note.Tags = inputNote.Tags;
    note.Excerpt = inputNote.Excerpt;
    note.Version = inputNote.Version;
    // and content when added to model

    await db.SaveChangesAsync();

    return Results.NoContent();
})
.WithName("UpdateNote")
.WithOpenApi();

app.MapDelete("/api/projects/{projectId}/notes/{noteId}", async (string projectId, string noteId, ChronicaeDbContext db) =>
{
    if (await db.Notes.FindAsync(noteId) is Note note && note.ProjectId == projectId)
    {
        db.Notes.Remove(note);
        await db.SaveChangesAsync();
        return Results.Ok(note);
    }

    return Results.NotFound();
})
.WithName("DeleteNote")
.WithOpenApi();
#endregion

app.Run();