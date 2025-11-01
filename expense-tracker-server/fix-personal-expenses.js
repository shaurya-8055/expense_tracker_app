// Fix personal_expenses table ID to use VARCHAR instead of UUID

const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.DATABASE_URL.includes('neon.tech') ? { rejectUnauthorized: false } : false
});

async function fixPersonalExpensesTable() {
    try {
        console.log('🔄 Fixing personal_expenses table ID column...');

        // Create new table with VARCHAR id
        await pool.query(`
            CREATE TABLE personal_expenses_new (
                id VARCHAR(255) PRIMARY KEY,
                user_id UUID REFERENCES users(id) ON DELETE CASCADE,
                title VARCHAR(255) NOT NULL,
                amount DECIMAL(10,2) NOT NULL,
                date TIMESTAMP NOT NULL,
                category INTEGER,
                note TEXT,
                description TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        `);

        // Check if old table has data and migrate if needed
        const dataCheck = await pool.query('SELECT COUNT(*) FROM personal_expenses');
        if (dataCheck.rows[0].count > 0) {
            console.log(`📦 Migrating ${dataCheck.rows[0].count} personal expenses...`);
            await pool.query(`
                INSERT INTO personal_expenses_new 
                (id, user_id, title, amount, date, category, note, description, created_at, updated_at)
                SELECT 
                    id::text, user_id, title, amount, date, 
                    category::integer, note, description, created_at, updated_at
                FROM personal_expenses
            `);
        }

        // Drop old table and rename new one
        await pool.query('DROP TABLE personal_expenses CASCADE');
        await pool.query('ALTER TABLE personal_expenses_new RENAME TO personal_expenses');

        // Recreate trigger
        await pool.query(`
            CREATE TRIGGER update_personal_expenses_updated_at BEFORE UPDATE ON personal_expenses
                FOR EACH ROW EXECUTE FUNCTION update_updated_at_column()
        `);

        // Recreate index
        await pool.query('CREATE INDEX idx_personal_expenses_user_id ON personal_expenses(user_id)');

        console.log('✅ Personal expenses table fixed successfully!');

        // Test the new structure
        const result = await pool.query(`
            SELECT column_name, data_type FROM information_schema.columns 
            WHERE table_name = 'personal_expenses' AND column_name = 'id'
        `);
        console.log('ID column type:', result.rows[0]);

    } catch (error) {
        console.error('❌ Fix failed:', error);
        throw error;
    } finally {
        await pool.end();
    }
}

fixPersonalExpensesTable().catch(console.error);