const { Pool } = require('pg');
const bcrypt = require('bcryptjs');
require('dotenv').config();

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.DATABASE_URL.includes('neon.tech') ? { rejectUnauthorized: false } : false
});

async function testUserRegistration() {
    try {
        console.log('🧪 Testing user registration...');
        
        const name = 'Test User';
        const phone = '+919026508435';
        const password = 'test123';
        const email = 'test@example.com';
        
        // Hash password
        const saltRounds = 10;
        const hashedPassword = await bcrypt.hash(password, saltRounds);
        
        // Insert user
        const insertResult = await pool.query(
            'INSERT INTO users (name, phone, email, password) VALUES ($1, $2, $3, $4) RETURNING id, name, phone, email, created_at, updated_at',
            [name, phone, email, hashedPassword]
        );
        
        const user = insertResult.rows[0];
        console.log('✅ User created successfully:', {
            id: user.id,
            name: user.name,
            phone: user.phone,
            email: user.email
        });
        
        // Verify user exists
        const countResult = await pool.query('SELECT COUNT(*) FROM users');
        console.log(`📊 Total users in database: ${countResult.rows[0].count}`);
        
        // Test password verification
        const userResult = await pool.query('SELECT * FROM users WHERE phone = $1', [phone]);
        const dbUser = userResult.rows[0];
        const isValidPassword = await bcrypt.compare(password, dbUser.password);
        console.log('🔐 Password verification:', isValidPassword ? '✅ Success' : '❌ Failed');
        
        process.exit(0);
    } catch (error) {
        console.error('❌ Test failed:', error.message);
        console.error('Full error:', error);
        process.exit(1);
    }
}

testUserRegistration();