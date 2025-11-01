// Check friends table structure
const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false }
});

async function checkFriendsTable() {
    try {
        // Check friends table structure
        const result = await pool.query(`
            SELECT column_name, data_type, is_nullable 
            FROM information_schema.columns 
            WHERE table_name = 'friends' 
            ORDER BY ordinal_position
        `);
        
        console.log('friends table structure:');
        result.rows.forEach(row => {
            console.log(`  ${row.column_name}: ${row.data_type} (nullable: ${row.is_nullable})`);
        });
        
        // Show sample friends data
        const sampleResult = await pool.query(`
            SELECT * FROM friends LIMIT 3
        `);
        
        console.log('\nSample friends data:');
        sampleResult.rows.forEach((row, index) => {
            console.log(`Friend ${index + 1}:`, row);
        });
        
    } catch (error) {
        console.error('Database check error:', error);
    } finally {
        await pool.end();
    }
}

checkFriendsTable();