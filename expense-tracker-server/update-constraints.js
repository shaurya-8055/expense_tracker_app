const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.DATABASE_URL.includes('neon.tech') ? { rejectUnauthorized: false } : false
});

async function updateUserTableConstraints() {
    try {
        console.log('🔧 Updating users table constraints...');
        
        // Make phone column unique
        try {
            await pool.query('ALTER TABLE users ADD CONSTRAINT users_phone_unique UNIQUE (phone)');
            console.log('✅ Phone uniqueness constraint added');
        } catch (error) {
            if (error.message.includes('already exists')) {
                console.log('ℹ️  Phone uniqueness constraint already exists');
            } else {
                throw error;
            }
        }
        
        // Make phone column NOT NULL
        try {
            await pool.query('ALTER TABLE users ALTER COLUMN phone SET NOT NULL');
            console.log('✅ Phone column set to NOT NULL');
        } catch (error) {
            if (error.message.includes('null value')) {
                console.log('⚠️  Cannot set phone to NOT NULL - existing null values found');
            } else {
                console.log('ℹ️  Phone column already NOT NULL or constraint exists');
            }
        }
        
        // Check final table structure
        const tableInfo = await pool.query(`
            SELECT column_name, data_type, is_nullable 
            FROM information_schema.columns 
            WHERE table_name = 'users' 
            ORDER BY ordinal_position
        `);
        
        console.log('📋 Final users table structure:');
        tableInfo.rows.forEach(row => {
            console.log(`  - ${row.column_name}: ${row.data_type} (nullable: ${row.is_nullable})`);
        });
        
        // Check constraints
        const constraints = await pool.query(`
            SELECT constraint_name, constraint_type 
            FROM information_schema.table_constraints 
            WHERE table_name = 'users'
        `);
        
        console.log('🔒 Table constraints:');
        constraints.rows.forEach(row => {
            console.log(`  - ${row.constraint_name}: ${row.constraint_type}`);
        });
        
        console.log('🎉 Database constraints updated successfully!');
        process.exit(0);
    } catch (error) {
        console.error('❌ Constraint update failed:', error.message);
        process.exit(1);
    }
}

updateUserTableConstraints();