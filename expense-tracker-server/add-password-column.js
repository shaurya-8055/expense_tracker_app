const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.DATABASE_URL.includes('neon.tech') ? { rejectUnauthorized: false } : false
});

async function addPasswordColumn() {
    try {
        console.log('🔧 Adding password column to users table...');
        
        // Add password column
        await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS password VARCHAR(255)');
        console.log('✅ Password column added');
        
        // Check table structure
        const tableInfo = await pool.query(`
            SELECT column_name, data_type, is_nullable 
            FROM information_schema.columns 
            WHERE table_name = 'users' 
            ORDER BY ordinal_position
        `);
        
        console.log('📋 Current users table structure:');
        tableInfo.rows.forEach(row => {
            console.log(`  - ${row.column_name}: ${row.data_type} (nullable: ${row.is_nullable})`);
        });
        
        console.log('🎉 Database schema updated successfully!');
        process.exit(0);
    } catch (error) {
        console.error('❌ Schema update failed:', error.message);
        process.exit(1);
    }
}

addPasswordColumn();