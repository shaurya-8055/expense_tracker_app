// Database migration to fix table schemas for the expense tracker app

const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.DATABASE_URL.includes('neon.tech') ? { rejectUnauthorized: false } : false
});

async function migrateDatabase() {
    try {
        console.log('🔄 Starting database migration...');

        // First, add password column to users table (if not already exists)
        console.log('Adding password column to users...');
        await pool.query(`
            ALTER TABLE users 
            ADD COLUMN IF NOT EXISTS password VARCHAR(255)
        `);

        // Update personal_expenses table structure
        console.log('Updating personal_expenses table...');
        
        // Add note column if it doesn't exist
        await pool.query(`
            ALTER TABLE personal_expenses 
            ADD COLUMN IF NOT EXISTS note TEXT
        `);

        // Copy description to note column if description exists and note is null
        await pool.query(`
            UPDATE personal_expenses 
            SET note = description 
            WHERE note IS NULL AND description IS NOT NULL
        `);

        // Update friends table structure - recreate it with the correct schema
        console.log('Updating friends table...');
        
        // Create new friends table with correct structure
        await pool.query(`
            CREATE TABLE IF NOT EXISTS friends_new (
                id VARCHAR(255) PRIMARY KEY,
                user_id UUID REFERENCES users(id) ON DELETE CASCADE,
                name VARCHAR(255) NOT NULL,
                phone_number VARCHAR(20),
                email VARCHAR(255),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        `);

        // Check if old friends table exists and has data
        const friendsCheck = await pool.query(`
            SELECT COUNT(*) as count FROM information_schema.tables 
            WHERE table_name = 'friends' AND table_schema = 'public'
        `);

        if (friendsCheck.rows[0].count > 0) {
            // Try to migrate existing data if possible
            try {
                await pool.query(`
                    INSERT INTO friends_new (id, user_id, name, phone_number, email, created_at)
                    SELECT 
                        COALESCE(id::text, gen_random_uuid()::text) as id,
                        user_id,
                        friend_name as name,
                        friend_phone as phone_number,
                        NULL as email,
                        created_at
                    FROM friends
                    ON CONFLICT (id) DO NOTHING
                `);
                console.log('✅ Migrated existing friends data');
            } catch (error) {
                console.log('⚠️  Could not migrate existing friends data:', error.message);
            }

            // Drop old friends table
            await pool.query('DROP TABLE friends CASCADE');
        }

        // Rename new table to friends
        await pool.query('ALTER TABLE friends_new RENAME TO friends');

        // Create trigger for friends updated_at
        await pool.query(`
            CREATE TRIGGER update_friends_updated_at BEFORE UPDATE ON friends
                FOR EACH ROW EXECUTE FUNCTION update_updated_at_column()
        `);

        // Create indexes
        await pool.query('CREATE INDEX IF NOT EXISTS idx_friends_user_id ON friends(user_id)');

        console.log('✅ Database migration completed successfully!');

        // Test the tables
        console.log('\n🧪 Testing table structures...');
        
        const personalExpensesCols = await pool.query(`
            SELECT column_name FROM information_schema.columns 
            WHERE table_name = 'personal_expenses' AND table_schema = 'public'
            ORDER BY column_name
        `);
        console.log('Personal expenses columns:', personalExpensesCols.rows.map(r => r.column_name));

        const friendsCols = await pool.query(`
            SELECT column_name FROM information_schema.columns 
            WHERE table_name = 'friends' AND table_schema = 'public'
            ORDER BY column_name
        `);
        console.log('Friends columns:', friendsCols.rows.map(r => r.column_name));

        console.log('\n✅ Migration completed successfully!');

    } catch (error) {
        console.error('❌ Migration failed:', error);
        throw error;
    } finally {
        await pool.end();
    }
}

// Run migration
migrateDatabase().catch(console.error);