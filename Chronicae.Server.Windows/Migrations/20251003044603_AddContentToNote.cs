using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Chronicae.Server.Windows.Migrations
{
    /// <inheritdoc />
    public partial class AddContentToNote : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Content",
                table: "Notes",
                type: "TEXT",
                nullable: false,
                defaultValue: "");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Content",
                table: "Notes");
        }
    }
}
