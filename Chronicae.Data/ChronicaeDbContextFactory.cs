using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace Chronicae.Data
{
    public class ChronicaeDbContextFactory : IDesignTimeDbContextFactory<ChronicaeDbContext>
    {
        public ChronicaeDbContext CreateDbContext(string[] args)
        {
            var optionsBuilder = new DbContextOptionsBuilder<ChronicaeDbContext>();
            optionsBuilder.UseSqlite("Data Source=chronicae.db");

            return new ChronicaeDbContext(optionsBuilder.Options);
        }
    }
}