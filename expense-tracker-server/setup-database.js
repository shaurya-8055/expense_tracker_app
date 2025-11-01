const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.DATABASE_URL.includes('neon.tech') ? { rejectUnauthorized: false } : false
});

async function setupDatabase() {
    const client = await pool.connect();
    
    try {
        console.log('🔧 Setting up database tables...');
        
        // Add password field to users table (for authentication)
        await client.query(`
            -- Create users table with password field for authentication
            CREATE TABLE IF NOT EXISTS users (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                name VARCHAR(255) NOT NULL,
                phone VARCHAR(20) UNIQUE NOT NULL,
                email VARCHAR(255),
                password VARCHAR(255) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        `);
        
        console.log('✅ Users table created/verified');
        
        // Create friends table
        await client.query(`
            CREATE TABLE IF NOT EXISTS friends (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id UUID REFERENCES users(id) ON DELETE CASCADE,
                friend_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
                friend_name VARCHAR(255) NOT NULL,
                friend_phone VARCHAR(20),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(user_id, friend_user_id)
            );
        `);
        
        console.log('✅ Friends table created/verified');
        
        // Create personal_expenses table  
        await client.query(`
            CREATE TABLE IF NOT EXISTS personal_expenses (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id UUID REFERENCES users(id) ON DELETE CASCADE,
                title VARCHAR(255) NOT NULL,
                description TEXT,
                amount DECIMAL(10,2) NOT NULL,
                category VARCHAR(100),
                date TIMESTAMP NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        `);
        
        console.log('✅ Personal expenses table created/verified');
        
        // Create group_expenses table
        await client.query(`
            CREATE TABLE IF NOT EXISTS group_expenses (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id UUID REFERENCES users(id) ON DELETE CASCADE,
                title VARCHAR(255) NOT NULL,
                description TEXT,
                total_amount DECIMAL(10,2) NOT NULL,
                paid_by VARCHAR(255) NOT NULL,
                participants JSON NOT NULL,
                splits JSON NOT NULL,
                date TIMESTAMP NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        `);
        
        console.log('✅ Group expenses table created/verified');
        
        // Create indexes
        await client.query(`
            CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);
            CREATE INDEX IF NOT EXISTS idx_friends_user_id ON friends(user_id);
            CREATE INDEX IF NOT EXISTS idx_personal_expenses_user_id ON personal_expenses(user_id);
            CREATE INDEX IF NOT EXISTS idx_group_expenses_user_id ON group_expenses(user_id);
        `);
        
        console.log('✅ Database indexes created/verified');
        
        // Check if we have any users
        const userCount = await client.query('SELECT COUNT(*) FROM users');
        console.log(`📊 Current users in database: ${userCount.rows[0].count}`);
        
        console.log('🎉 Database setup completed successfully!');
        
    } catch (error) {
        console.error('❌ Database setup error:', error);
        throw error;
    } finally {
        client.release();
    }
}

if (require.main === module) {
    setupDatabase()
        .then(() => {
            console.log('Database setup finished');
            process.exit(0);
        })
        .catch(error => {
            console.error('Setup failed:', error);
            process.exit(1);
        });
}

module.exports = { setupDatabase, pool };