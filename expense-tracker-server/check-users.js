const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.DATABASE_URL.includes('neon.tech') ? { rejectUnauthorized: false } : false
});

async function checkUsers() {
    try {
        const result = await pool.query('SELECT id, name, phone, email, created_at FROM users ORDER BY created_at DESC');
        
        console.log('📊 Users in your Neon database:');
        console.log('=====================================');
        
        if (result.rows.length === 0) {
            console.log('❌ No users found in the database');
        } else {
            result.rows.forEach((user, i) => {
                console.log(`${i+1}. ${user.name} (${user.phone})`);
                console.log(`   Email: ${user.email || 'Not provided'}`);
                console.log(`   ID: ${user.id}`);
                console.log(`   Created: ${user.created_at}`);
                console.log('');
            });
            console.log(`✅ Total users: ${result.rows.length}`);
        }
        
        process.exit(0);
    } catch (error) {
        console.error('❌ Database error:', error.message);
        process.exit(1);
    }
}

checkUsers();