// Migration to add friend invitation system and shared expenses

const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.DATABASE_URL.includes('neon.tech') ? { rejectUnauthorized: false } : false
});

async function addFriendInvitationSystem() {
    try {
        console.log('🔄 Adding friend invitation system...');

        // Add status column to friends table
        await pool.query(`
            ALTER TABLE friends 
            ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'accepted'
        `);

        // Create friend_invitations table
        await pool.query(`
            CREATE TABLE IF NOT EXISTS friend_invitations (
                id VARCHAR(255) PRIMARY KEY,
                inviter_id UUID REFERENCES users(id) ON DELETE CASCADE,
                inviter_name VARCHAR(255) NOT NULL,
                friend_phone VARCHAR(20) NOT NULL,
                friend_name VARCHAR(255) NOT NULL,
                status VARCHAR(20) DEFAULT 'pending',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        `);

        // Create shared_expenses table
        await pool.query(`
            CREATE TABLE IF NOT EXISTS shared_expenses (
                id VARCHAR(255) PRIMARY KEY,
                creator_id UUID REFERENCES users(id) ON DELETE CASCADE,
                title VARCHAR(255) NOT NULL,
                amount DECIMAL(10,2) NOT NULL,
                date TIMESTAMP NOT NULL,
                participants UUID[] NOT NULL,
                splits JSONB NOT NULL,
                note TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        `);

        // Create indexes
        await pool.query('CREATE INDEX IF NOT EXISTS idx_friend_invitations_phone ON friend_invitations(friend_phone)');
        await pool.query('CREATE INDEX IF NOT EXISTS idx_friend_invitations_status ON friend_invitations(status)');
        await pool.query('CREATE INDEX IF NOT EXISTS idx_shared_expenses_creator ON shared_expenses(creator_id)');
        await pool.query('CREATE INDEX IF NOT EXISTS idx_shared_expenses_participants ON shared_expenses USING GIN(participants)');

        // Create triggers for updated_at
        await pool.query(`
            CREATE TRIGGER update_friend_invitations_updated_at BEFORE UPDATE ON friend_invitations
                FOR EACH ROW EXECUTE FUNCTION update_updated_at_column()
        `);

        await pool.query(`
            CREATE TRIGGER update_shared_expenses_updated_at BEFORE UPDATE ON shared_expenses
                FOR EACH ROW EXECUTE FUNCTION update_updated_at_column()
        `);

        console.log('✅ Friend invitation system added successfully!');

        // Test the new tables
        console.log('\n🧪 Testing new table structures...');
        
        const invitationsCols = await pool.query(`
            SELECT column_name FROM information_schema.columns 
            WHERE table_name = 'friend_invitations' AND table_schema = 'public'
            ORDER BY column_name
        `);
        console.log('Friend invitations columns:', invitationsCols.rows.map(r => r.column_name));

        const sharedExpensesCols = await pool.query(`
            SELECT column_name FROM information_schema.columns 
            WHERE table_name = 'shared_expenses' AND table_schema = 'public'
            ORDER BY column_name
        `);
        console.log('Shared expenses columns:', sharedExpensesCols.rows.map(r => r.column_name));

        const friendsCols = await pool.query(`
            SELECT column_name FROM information_schema.columns 
            WHERE table_name = 'friends' AND table_schema = 'public'
            ORDER BY column_name
        `);
        console.log('Updated friends columns:', friendsCols.rows.map(r => r.column_name));

        console.log('\n✅ Friend invitation system migration completed!');

    } catch (error) {
        console.error('❌ Migration failed:', error);
        throw error;
    } finally {
        await pool.end();
    }
}

addFriendInvitationSystem().catch(console.error);