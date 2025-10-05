using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Chronicae.Data.Migrations
{
    /// <inheritdoc />
    public partial class InitialCreate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "BackupRecords",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    StartedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                    CompletedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                    Status = table.Column<string>(type: "TEXT", nullable: false),
                    ArtifactPath = table.Column<string>(type: "TEXT", maxLength: 1000, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_BackupRecords", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Projects",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    Name = table.Column<string>(type: "TEXT", maxLength: 500, nullable: false),
                    NoteCount = table.Column<int>(type: "INTEGER", nullable: false, defaultValue: 0),
                    LastIndexedAt = table.Column<DateTime>(type: "TEXT", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Projects", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Notes",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    ProjectId = table.Column<Guid>(type: "TEXT", nullable: false),
                    Title = table.Column<string>(type: "TEXT", maxLength: 1000, nullable: false),
                    Content = table.Column<string>(type: "TEXT", nullable: false),
                    Excerpt = table.Column<string>(type: "TEXT", maxLength: 500, nullable: true),
                    Tags = table.Column<string>(type: "TEXT", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                    Version = table.Column<int>(type: "INTEGER", nullable: false, defaultValue: 1)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Notes", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Notes_Projects_ProjectId",
                        column: x => x.ProjectId,
                        principalTable: "Projects",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "NoteVersions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    NoteId = table.Column<Guid>(type: "TEXT", nullable: false),
                    Title = table.Column<string>(type: "TEXT", maxLength: 1000, nullable: false),
                    Content = table.Column<string>(type: "TEXT", nullable: false),
                    Excerpt = table.Column<string>(type: "TEXT", maxLength: 500, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                    Version = table.Column<int>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_NoteVersions", x => x.Id);
                    table.ForeignKey(
                        name: "FK_NoteVersions_Notes_NoteId",
                        column: x => x.NoteId,
                        principalTable: "Notes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "ExportJobs",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    ProjectId = table.Column<Guid>(type: "TEXT", nullable: true),
                    NoteId = table.Column<Guid>(type: "TEXT", nullable: true),
                    VersionId = table.Column<Guid>(type: "TEXT", nullable: true),
                    Format = table.Column<string>(type: "TEXT", maxLength: 50, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                    CompletedAt = table.Column<DateTime>(type: "TEXT", nullable: true),
                    Status = table.Column<string>(type: "TEXT", maxLength: 50, nullable: false),
                    ArtifactPath = table.Column<string>(type: "TEXT", maxLength: 1000, nullable: true),
                    ErrorMessage = table.Column<string>(type: "TEXT", maxLength: 2000, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ExportJobs", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ExportJobs_NoteVersions_VersionId",
                        column: x => x.VersionId,
                        principalTable: "NoteVersions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_ExportJobs_Notes_NoteId",
                        column: x => x.NoteId,
                        principalTable: "Notes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_ExportJobs_Projects_ProjectId",
                        column: x => x.ProjectId,
                        principalTable: "Projects",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateIndex(
                name: "IX_BackupRecords_StartedAt",
                table: "BackupRecords",
                column: "StartedAt");

            migrationBuilder.CreateIndex(
                name: "IX_BackupRecords_Status",
                table: "BackupRecords",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_ExportJobs_CreatedAt",
                table: "ExportJobs",
                column: "CreatedAt");

            migrationBuilder.CreateIndex(
                name: "IX_ExportJobs_NoteId",
                table: "ExportJobs",
                column: "NoteId");

            migrationBuilder.CreateIndex(
                name: "IX_ExportJobs_ProjectId",
                table: "ExportJobs",
                column: "ProjectId");

            migrationBuilder.CreateIndex(
                name: "IX_ExportJobs_Status",
                table: "ExportJobs",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_ExportJobs_VersionId",
                table: "ExportJobs",
                column: "VersionId");

            migrationBuilder.CreateIndex(
                name: "IX_Notes_CreatedAt",
                table: "Notes",
                column: "CreatedAt");

            migrationBuilder.CreateIndex(
                name: "IX_Notes_ProjectId_UpdatedAt",
                table: "Notes",
                columns: new[] { "ProjectId", "UpdatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_Notes_Title",
                table: "Notes",
                column: "Title");

            migrationBuilder.CreateIndex(
                name: "IX_Notes_UpdatedAt",
                table: "Notes",
                column: "UpdatedAt");

            migrationBuilder.CreateIndex(
                name: "IX_NoteVersions_CreatedAt",
                table: "NoteVersions",
                column: "CreatedAt");

            migrationBuilder.CreateIndex(
                name: "IX_NoteVersions_NoteId_CreatedAt",
                table: "NoteVersions",
                columns: new[] { "NoteId", "CreatedAt" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "BackupRecords");

            migrationBuilder.DropTable(
                name: "ExportJobs");

            migrationBuilder.DropTable(
                name: "NoteVersions");

            migrationBuilder.DropTable(
                name: "Notes");

            migrationBuilder.DropTable(
                name: "Projects");
        }
    }
}
