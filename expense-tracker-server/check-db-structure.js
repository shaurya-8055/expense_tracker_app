// Check database structure
const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false }
});

async function checkDatabase() {
    try {
        // Check personal_expenses table structure
        const result = await pool.query(`
            SELECT column_name, data_type, is_nullable 
            FROM information_schema.columns 
            WHERE table_name = 'personal_expenses' 
            ORDER BY ordinal_position
        `);
        
        console.log('personal_expenses table structure:');
        result.rows.forEach(row => {
            console.log(`  ${row.column_name}: ${row.data_type} (nullable: ${row.is_nullable})`);
        });
        
        // Check shared_expenses table structure
        const sharedResult = await pool.query(`
            SELECT column_name, data_type, is_nullable 
            FROM information_schema.columns 
            WHERE table_name = 'shared_expenses' 
            ORDER BY ordinal_position
        `);
        
        console.log('\nshared_expenses table structure:');
        sharedResult.rows.forEach(row => {
            console.log(`  ${row.column_name}: ${row.data_type} (nullable: ${row.is_nullable})`);
        });
        
    } catch (error) {
        console.error('Database check error:', error);
    } finally {
        await pool.end();
    }
}

checkDatabase();