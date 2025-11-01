const WebSocket = require('ws');
const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
require('dotenv').config();

const app = express();
const port = process.env.PORT || 8080;

// Database connection
const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.DATABASE_URL.includes('neon.tech') ? { rejectUnauthorized: false } : false
});

// Middleware
app.use(cors());
app.use(express.json());

// Store WebSocket connections
const connections = new Map();

// Create HTTP server
const server = require('http').createServer(app);

// Create WebSocket server
const wss = new WebSocket.Server({ server });

// WebSocket connection handler
wss.on('connection', (ws, req) => {
    console.log('New WebSocket connection');
    
    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);
            
            if (data.type === 'auth') {
                // Store user ID with connection
                connections.set(ws, data.userId);
                ws.send(JSON.stringify({ type: 'auth_success' }));
                console.log(`User ${data.userId} authenticated`);
            }
        } catch (error) {
            console.error('WebSocket message error:', error);
        }
    });
    
    ws.on('close', () => {
        connections.delete(ws);
        console.log('WebSocket connection closed');
    });
});

// Broadcast to all connected clients except sender
function broadcast(senderId, data) {
    let broadcastCount = 0;
    connections.forEach((userId, ws) => {
        if (userId !== senderId && ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify(data));
            broadcastCount++;
        }
    });
    console.log(`Broadcasted to ${broadcastCount} clients`);
}

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// Authentication dependencies
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';

// Authentication middleware
const authenticateToken = async (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
        return res.status(401).json({ message: 'Access token required' });
    }

    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        
        // Verify user exists in database
        const userResult = await pool.query('SELECT id, name, phone, email FROM users WHERE id = $1', [decoded.userId]);
        if (userResult.rows.length === 0) {
            return res.status(403).json({ message: 'User not found' });
        }
        
        req.user = userResult.rows[0];
        req.userId = decoded.userId;
        next();
    } catch (err) {
        return res.status(403).json({ message: 'Invalid or expired token' });
    }
};

// REST API Routes

// Authentication - Register
app.post('/auth/register', async (req, res) => {
    try {
        const { name, phone, password, email } = req.body;
        
        // Validate required fields
        if (!name || !phone || !password) {
            return res.status(400).json({ message: 'Name, phone, and password are required' });
        }
        
        // Check if user already exists in database
        const existingUserResult = await pool.query('SELECT id FROM users WHERE phone = $1', [phone]);
        if (existingUserResult.rows.length > 0) {
            return res.status(400).json({ message: 'User with this phone number already exists' });
        }
        
        // Hash password
        const saltRounds = 10;
        const hashedPassword = await bcrypt.hash(password, saltRounds);
        
        // Create new user in database
        const insertResult = await pool.query(
            'INSERT INTO users (name, phone, email, password) VALUES ($1, $2, $3, $4) RETURNING id, name, phone, email, created_at, updated_at',
            [name, phone, email || null, hashedPassword]
        );
        
        const user = insertResult.rows[0];
        
        // Generate JWT token
        const token = jwt.sign({ userId: user.id, phone: user.phone }, JWT_SECRET, { expiresIn: '30d' });
        
        // Return user data without password
        const userResponse = {
            id: user.id,
            name: user.name,
            phone: user.phone,
            email: user.email,
            createdAt: user.created_at,
            updatedAt: user.updated_at
        };
        
        console.log(`New user registered: ${name} (${phone})`);
        res.status(201).json({ 
            message: 'User registered successfully',
            user: userResponse, 
            token 
        });
    } catch (error) {
        console.error('Registration error:', error);
        res.status(500).json({ message: 'Registration failed' });
    }
});

// Authentication - Login
app.post('/auth/login', async (req, res) => {
    try {
        const { phone, password } = req.body;
        
        // Validate required fields
        if (!phone || !password) {
            return res.status(400).json({ message: 'Phone and password are required' });
        }
        
        // Check if user exists in database
        const userResult = await pool.query('SELECT * FROM users WHERE phone = $1', [phone]);
        if (userResult.rows.length === 0) {
            return res.status(401).json({ message: 'Invalid phone number or password' });
        }
        
        const user = userResult.rows[0];
        
        // Verify password
        const isValidPassword = await bcrypt.compare(password, user.password);
        if (!isValidPassword) {
            return res.status(401).json({ message: 'Invalid phone number or password' });
        }
        
        // Generate JWT token
        const token = jwt.sign({ userId: user.id, phone }, JWT_SECRET, { expiresIn: '30d' });
        
        // Return user data without password
        const userResponse = {
            id: user.id,
            name: user.name,
            phone: user.phone,
            email: user.email,
            createdAt: user.created_at,
            updatedAt: user.updated_at
        };
        
        console.log(`User login: ${user.name} (${phone})`);
        res.json({ 
            message: 'Login successful',
            user: userResponse, 
            token 
        });
    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({ message: 'Login failed' });
    }
});

// Authentication - Get Profile
app.get('/auth/profile', authenticateToken, async (req, res) => {
    try {
        // User data is already loaded in authenticateToken middleware
        const userResponse = {
            id: req.user.id,
            name: req.user.name,
            phone: req.user.phone,
            email: req.user.email
        };
        
        res.json({ user: userResponse });
    } catch (error) {
        console.error('Get profile error:', error);
        res.status(500).json({ message: 'Failed to get profile' });
    }
});

// Authentication - Update Profile
app.put('/auth/profile', authenticateToken, async (req, res) => {
    try {
        const { name, email } = req.body;
        
        // Update user in database
        const updateResult = await pool.query(
            'UPDATE users SET name = COALESCE($1, name), email = COALESCE($2, email), updated_at = CURRENT_TIMESTAMP WHERE id = $3 RETURNING id, name, phone, email, created_at, updated_at',
            [name, email, req.userId]
        );
        
        if (updateResult.rows.length === 0) {
            return res.status(404).json({ message: 'User not found' });
        }
        
        const user = updateResult.rows[0];
        
        // Return updated user data
        const userResponse = {
            id: user.id,
            name: user.name,
            phone: user.phone,
            email: user.email,
            createdAt: user.created_at,
            updatedAt: user.updated_at
        };
        
        console.log(`Profile updated for user: ${user.name}`);
        res.json({ 
            message: 'Profile updated successfully',
            user: userResponse 
        });
    } catch (error) {
        console.error('Update profile error:', error);
        res.status(500).json({ message: 'Failed to update profile' });
    }
});

// Authentication - Change Password
app.put('/auth/change-password', authenticateToken, async (req, res) => {
    try {
        const { currentPassword, newPassword } = req.body;
        
        // Get current user with password from database
        const userResult = await pool.query('SELECT * FROM users WHERE id = $1', [req.userId]);
        if (userResult.rows.length === 0) {
            return res.status(404).json({ message: 'User not found' });
        }
        
        const user = userResult.rows[0];
        
        // Verify current password
        const isValidPassword = await bcrypt.compare(currentPassword, user.password);
        if (!isValidPassword) {
            return res.status(401).json({ message: 'Current password is incorrect' });
        }
        
        // Hash new password
        const saltRounds = 10;
        const hashedPassword = await bcrypt.hash(newPassword, saltRounds);
        
        // Update password in database
        await pool.query(
            'UPDATE users SET password = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2',
            [hashedPassword, req.userId]
        );
        
        console.log(`Password changed for user: ${user.name}`);
        res.json({ message: 'Password changed successfully' });
    } catch (error) {
        console.error('Change password error:', error);
        res.status(500).json({ message: 'Failed to change password' });
    }
});

// Authentication - Verify Phone
app.post('/auth/verify-phone', async (req, res) => {
    try {
        const { phone } = req.body;
        
        // Check if phone exists in database
        const userResult = await pool.query('SELECT id FROM users WHERE phone = $1', [phone]);
        const exists = userResult.rows.length > 0;
        
        console.log(`Phone verification check for ${phone}: ${exists}`);
        res.json({ 
            message: 'Phone verification check completed',
            exists 
        });
    } catch (error) {
        console.error('Phone verification error:', error);
        res.status(500).json({ message: 'Phone verification failed' });
    }
});

// User management endpoints for contact integration
app.post('/api/users/check', async (req, res) => {
    try {
        const { phone } = req.body;
        
        const result = await pool.query(
            'SELECT id FROM users WHERE phone = $1',
            [phone]
        );
        
        const exists = result.rows.length > 0;
        
        console.log(`Checking if user exists for phone ${phone}: ${exists}`);
        res.json({ exists });
    } catch (error) {
        console.error('Check user error:', error);
        res.status(500).json({ error: 'Failed to check user' });
    }
});

app.post('/api/users/by-phone', async (req, res) => {
    try {
        const { phone } = req.body;
        
        const result = await pool.query(
            'SELECT id, name, phone, email, created_at FROM users WHERE phone = $1',
            [phone]
        );
        
        if (result.rows.length > 0) {
            const user = {
                id: result.rows[0].id,
                name: result.rows[0].name,
                phone: result.rows[0].phone,
                email: result.rows[0].email
            };
            
            console.log(`Found user by phone ${phone}: ${user.name}`);
            res.json({ user });
        } else {
            res.status(404).json({ error: 'User not found' });
        }
    } catch (error) {
        console.error('Get user by phone error:', error);
        res.status(500).json({ error: 'Failed to get user' });
    }
});

app.post('/api/users/register', async (req, res) => {
    try {
        const { name, phone, email } = req.body;
        
        // Check if user already exists
        if (usersByPhone.has(phone)) {
            return res.status(400).json({ error: 'User already exists' });
        }
        
        const userId = `user_${Date.now()}_${Math.random().toString(36).substring(7)}`;
        const user = { id: userId, name, phone, email, createdAt: new Date() };
        
        users.set(userId, user);
        usersByPhone.set(phone, user);
        
        console.log(`User registered: ${name} (${phone})`);
        res.status(201).json({ user });
    } catch (error) {
        console.error('Register user error:', error);
        res.status(500).json({ error: 'Failed to register user' });
    }
});

app.post('/api/users/search', authenticateToken, async (req, res) => {
    try {
        const { query } = req.body;
        const currentUserId = req.user.id;
        
        const result = await pool.query(
            `SELECT id, name, phone, email FROM users 
             WHERE id != $1 AND (
                 LOWER(name) LIKE LOWER($2) OR 
                 phone LIKE $3 OR 
                 LOWER(email) LIKE LOWER($2)
             ) 
             ORDER BY name ASC 
             LIMIT 50`,
            [currentUserId, `%${query}%`, `%${query}%`]
        );
        
        const users = result.rows.map(row => ({
            id: row.id,
            name: row.name,
            phone: row.phone,
            email: row.email
        }));
        
        console.log(`Search for "${query}" returned ${users.length} results`);
        res.json({ users });
    } catch (error) {
        console.error('Search users error:', error);
        res.status(500).json({ error: 'Failed to search users' });
    }
});

// Friends API
app.get('/api/friends', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        
        const result = await pool.query(
            `SELECT id, name, phone_number, email, created_at 
             FROM friends 
             WHERE user_id = $1 
             ORDER BY name ASC`,
            [userId]
        );
        
        const friends = result.rows.map(row => ({
            id: row.id,
            name: row.name,
            phoneNumber: row.phone_number,
            email: row.email
        }));
        
        res.json(friends);
    } catch (error) {
        console.error('Get friends error:', error);
        res.status(500).json({ error: 'Failed to get friends' });
    }
});

app.post('/api/friends', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const { id, name, phoneNumber, email } = req.body;
        
        await pool.query(
            `INSERT INTO friends (id, user_id, name, phone_number, email, created_at) 
             VALUES ($1, $2, $3, $4, $5, NOW())`,
            [id, userId, name, phoneNumber, email]
        );
        
        console.log(`Added friend for user ${userId}:`, { id, name, phoneNumber });
        
        // Broadcast to other users
        broadcast(userId, {
            type: 'friend_added',
            data: { id, name, phoneNumber, email },
            userId: userId
        });
        
        res.json({ success: true, id });
    } catch (error) {
        console.error('Add friend error:', error);
        res.status(500).json({ error: 'Failed to add friend' });
    }
});

app.put('/api/friends/:id', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const friendId = req.params.id;
        const { name, phoneNumber, email } = req.body;
        
        const result = await pool.query(
            `UPDATE friends 
             SET name = $1, phone_number = $2, email = $3, updated_at = NOW()
             WHERE id = $4 AND user_id = $5`,
            [name, phoneNumber, email, friendId, userId]
        );
        
        if (result.rowCount === 0) {
            return res.status(404).json({ error: 'Friend not found or access denied' });
        }
        
        console.log(`Updated friend ${friendId} for user ${userId}`);
        
        res.json({ success: true });
    } catch (error) {
        console.error('Update friend error:', error);
        res.status(500).json({ error: 'Failed to update friend' });
    }
});

app.delete('/api/friends/:id', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const friendId = req.params.id;
        
        const result = await pool.query(
            `DELETE FROM friends WHERE id = $1 AND user_id = $2`,
            [friendId, userId]
        );
        
        if (result.rowCount === 0) {
            return res.status(404).json({ error: 'Friend not found or access denied' });
        }
        
        console.log(`Deleted friend ${friendId} for user ${userId}`);
        
        res.json({ success: true });
    } catch (error) {
        console.error('Delete friend error:', error);
        res.status(500).json({ error: 'Failed to delete friend' });
    }
});

// Friend Invitation System
app.post('/api/friends/invite', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const { friendPhone, friendName } = req.body;
        
        // Create a pending friend invitation
        const invitationId = `inv_${Date.now()}`;
        
        await pool.query(
            `INSERT INTO friend_invitations (id, inviter_id, inviter_name, friend_phone, friend_name, status, created_at) 
             VALUES ($1, $2, $3, $4, $5, 'pending', NOW())`,
            [invitationId, userId, req.user.name, friendPhone, friendName]
        );
        
        // Also add to friends table for immediate display (with pending status)
        const friendId = `friend_${Date.now()}`;
        await pool.query(
            `INSERT INTO friends (id, user_id, name, phone_number, email, status, created_at) 
             VALUES ($1, $2, $3, $4, NULL, 'pending', NOW())`,
            [friendId, userId, friendName, friendPhone]
        );
        
        console.log(`Created friend invitation for ${friendPhone} by user ${userId}`);
        
        res.json({ success: true, invitationId, friendId });
    } catch (error) {
        console.error('Create friend invitation error:', error);
        res.status(500).json({ error: 'Failed to create friend invitation' });
    }
});

app.get('/api/friends/pending', authenticateToken, async (req, res) => {
    try {
        const userPhone = req.user.phone;
        
        const result = await pool.query(
            `SELECT fi.id, fi.inviter_id, fi.inviter_name, fi.friend_name, fi.created_at,
                    u.name as inviter_name, u.email as inviter_email
             FROM friend_invitations fi
             JOIN users u ON fi.inviter_id = u.id
             WHERE fi.friend_phone = $1 AND fi.status = 'pending'
             ORDER BY fi.created_at DESC`,
            [userPhone]
        );
        
        const invitations = result.rows.map(row => ({
            id: row.id,
            inviterId: row.inviter_id,
            inviterName: row.inviter_name,
            inviterEmail: row.inviter_email,
            friendName: row.friend_name,
            createdAt: row.created_at
        }));
        
        res.json(invitations);
    } catch (error) {
        console.error('Get pending invitations error:', error);
        res.status(500).json({ error: 'Failed to get pending invitations' });
    }
});

app.post('/api/friends/accept', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const { invitationId } = req.body;
        
        // Get invitation details
        const inviteResult = await pool.query(
            `SELECT * FROM friend_invitations WHERE id = $1 AND status = 'pending'`,
            [invitationId]
        );
        
        if (inviteResult.rows.length === 0) {
            return res.status(404).json({ error: 'Invitation not found' });
        }
        
        const invitation = inviteResult.rows[0];
        
        // Add both users as friends to each other
        const friendId1 = `friend_${Date.now()}_1`;
        const friendId2 = `friend_${Date.now()}_2`;
        
        // Add inviter as friend to current user
        await pool.query(
            `INSERT INTO friends (id, user_id, name, phone_number, email, status, created_at) 
             VALUES ($1, $2, $3, (SELECT phone FROM users WHERE id = $4), 
                     (SELECT email FROM users WHERE id = $4), 'accepted', NOW())`,
            [friendId1, userId, invitation.inviter_name, invitation.inviter_id]
        );
        
        // Add current user as friend to inviter (update existing pending friend)
        await pool.query(
            `UPDATE friends 
             SET name = $1, email = $2, status = 'accepted', updated_at = NOW()
             WHERE user_id = $3 AND phone_number = $4`,
            [req.user.name, req.user.email, invitation.inviter_id, req.user.phone]
        );
        
        // Mark invitation as accepted
        await pool.query(
            `UPDATE friend_invitations SET status = 'accepted', updated_at = NOW() WHERE id = $1`,
            [invitationId]
        );
        
        console.log(`Accepted friend invitation ${invitationId}`);
        
        res.json({ success: true });
    } catch (error) {
        console.error('Accept friend invitation error:', error);
        res.status(500).json({ error: 'Failed to accept friend invitation' });
    }
});

app.get('/api/expenses/shared', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        
        // Get shared expenses where user is either creator or participant
        const result = await pool.query(
            `SELECT se.*, u.name as creator_name
             FROM shared_expenses se
             JOIN users u ON se.creator_id = u.id
             WHERE se.creator_id = $1 
                OR $1 = ANY(se.participants)
             ORDER BY se.date DESC, se.created_at DESC`,
            [userId]
        );
        
        const expenses = result.rows.map(row => ({
            id: row.id,
            title: row.title,
            amount: parseFloat(row.amount),
            date: row.date,
            creatorId: row.creator_id,
            creatorName: row.creator_name,
            participants: row.participants,
            splits: row.splits,
            note: row.note
        }));
        
        res.json(expenses);
    } catch (error) {
        console.error('Get shared expenses error:', error);
        res.status(500).json({ error: 'Failed to get shared expenses' });
    }
});

// Group Expenses API
app.get('/api/group-expenses', async (req, res) => {
    try {
        const userId = req.headers.authorization?.replace('Bearer ', '');
        
        // For development, return mock data
        res.json([
            {
                id: 'expense_1',
                title: 'Dinner at Restaurant',
                description: 'Team dinner',
                totalAmount: 1200.0,
                paidBy: 'me',
                participants: ['me', 'friend_1', 'friend_2'],
                splits: {
                    'me': 400.0,
                    'friend_1': 400.0,
                    'friend_2': 400.0
                },
                date: new Date().toISOString(),
                category: 1
            }
        ]);
    } catch (error) {
        console.error('Get group expenses error:', error);
        res.status(500).json({ error: 'Failed to get group expenses' });
    }
});

app.post('/api/group-expenses', async (req, res) => {
    try {
        const userId = req.headers.authorization?.replace('Bearer ', '');
        const expense = req.body;
        
        console.log(`Adding group expense for user ${userId}:`, expense);
        
        // Broadcast to other users
        broadcast(userId, {
            type: 'group_expense_added',
            data: expense,
            userId: userId
        });
        
        res.json({ success: true, expense });
    } catch (error) {
        console.error('Add group expense error:', error);
        res.status(500).json({ error: 'Failed to add group expense' });
    }
});

// Personal Expenses API
app.get('/api/personal-expenses', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        
        const result = await pool.query(
            `SELECT id, title, amount, date, category, note, created_at 
             FROM personal_expenses 
             WHERE user_id = $1 
             ORDER BY date DESC, created_at DESC`,
            [userId]
        );
        
        const expenses = result.rows.map(row => ({
            id: row.id,
            title: row.title,
            amount: parseFloat(row.amount),
            date: row.date,
            category: row.category,
            note: row.note
        }));
        
        res.json(expenses);
    } catch (error) {
        console.error('Get personal expenses error:', error);
        res.status(500).json({ error: 'Failed to get personal expenses' });
    }
});

// General expense endpoint that handles both personal and shared expenses
app.post('/api/expenses', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const { description, amount, category, type, sharedWith } = req.body;
        const expenseId = `exp_${Date.now()}_${Math.random().toString(36).substring(7)}`;
        const currentDate = new Date().toISOString().split('T')[0];
        
        // Map category strings to integers
        const categoryMap = {
            'Food': 1,
            'Transportation': 2,
            'Entertainment': 3,
            'Shopping': 4,
            'Bills': 5,
            'Healthcare': 6,
            'Education': 7,
            'Travel': 8,
            'Other': 9
        };
        
        const categoryId = categoryMap[category] || 9; // Default to 'Other'
        
        if (type === 'shared' && sharedWith && sharedWith.length > 0) {
            // Create shared expense
            console.log('Creating shared expense:', { description, amount, category, sharedWith });
            
            // First, create the main expense record
            await pool.query(
                `INSERT INTO personal_expenses (id, user_id, title, amount, date, category, description, created_at) 
                 VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())`,
                [expenseId, userId, description, amount, currentDate, categoryId, `Shared expense with ${sharedWith.length} friend(s)`]
            );
            
            // Then create shared expense records for each friend
            for (const share of sharedWith) {
                const sharedExpenseId = `shared_${Date.now()}_${Math.random().toString(36).substring(7)}`;
                
                // Get friend's user ID from friend's phone number
                const friendResult = await pool.query(
                    'SELECT phone_number FROM friends WHERE id = $1 AND user_id = $2',
                    [share.friendId, userId]
                );
                
                if (friendResult.rows.length > 0) {
                    const friendPhone = friendResult.rows[0].phone_number;
                    
                    // Get friend's user ID from users table
                    const userResult = await pool.query(
                        'SELECT id FROM users WHERE phone = $1',
                        [friendPhone]
                    );
                    
                    if (userResult.rows.length > 0) {
                        const friendUserId = userResult.rows[0].id;
                    
                        // For now, let's create a simple shared expense record
                        // We need to match the existing shared_expenses table structure
                        await pool.query(
                            `INSERT INTO shared_expenses (id, creator_id, title, amount, date, participants, splits, note, created_at) 
                             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())`,
                            [
                                sharedExpenseId, 
                                userId, 
                                description, 
                                amount, 
                                currentDate,
                                [userId, friendUserId], // PostgreSQL array format
                                { [userId]: amount - share.amount, [friendUserId]: share.amount }, // JSONB object
                                `Shared with friend - ${share.amount} amount`
                            ]
                        );
                        
                        console.log(`Created shared expense record for friend ${friendUserId}: ${share.amount}`);
                    }
                }
            }
            
            res.json({ success: true, id: expenseId, type: 'shared' });
        } else {
            // Create personal expense
            await pool.query(
                `INSERT INTO personal_expenses (id, user_id, title, amount, date, category, description, created_at) 
                 VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())`,
                [expenseId, userId, description, amount, currentDate, categoryId, 'Personal expense']
            );
            
            res.json({ success: true, id: expenseId, type: 'personal' });
        }
        
    } catch (error) {
        console.error('Add expense error:', error);
        console.error('Full error details:', error.message, error.stack);
        res.status(500).json({ error: 'Failed to add expense', details: error.message });
    }
});

// Get all expenses for a user (personal + shared)
app.get('/api/expenses', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        
        // Get personal expenses
        const personalResult = await pool.query(
            `SELECT id, title as description, amount, date, category, description as note, created_at, 'personal' as type
             FROM personal_expenses 
             WHERE user_id = $1 
             ORDER BY created_at DESC`,
            [userId]
        );
        
        // Get shared expenses where user is creator or participant
        const sharedResult = await pool.query(
            `SELECT se.id, se.title as description, se.amount, se.date, se.created_at, 'shared' as type,
                    CASE WHEN se.creator_id = $1 THEN 'created' ELSE 'participant' END as role
             FROM shared_expenses se
             WHERE se.creator_id = $1 OR $1 = ANY(se.participants)
             ORDER BY se.created_at DESC`,
            [userId]
        );
        
        // Combine and sort all expenses
        const allExpenses = [...personalResult.rows, ...sharedResult.rows]
            .sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
        
        res.json(allExpenses);
    } catch (error) {
        console.error('Get expenses error:', error);
        res.status(500).json({ error: 'Failed to get expenses' });
    }
});

app.post('/api/personal-expenses', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const { id, title, amount, date, category, note } = req.body;
        
        await pool.query(
            `INSERT INTO personal_expenses (id, user_id, title, amount, date, category, note, created_at) 
             VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())`,
            [id, userId, title, amount, date, category, note]
        );
        
        console.log(`Added personal expense for user ${userId}:`, { id, title, amount });
        
        res.json({ success: true, id });
    } catch (error) {
        console.error('Add personal expense error:', error);
        console.error('Full error details:', error.message, error.stack);
        res.status(500).json({ error: 'Failed to add personal expense', details: error.message });
    }
});

app.put('/api/personal-expenses/:id', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const expenseId = req.params.id;
        const { title, amount, date, category, note } = req.body;
        
        const result = await pool.query(
            `UPDATE personal_expenses 
             SET title = $1, amount = $2, date = $3, category = $4, note = $5, updated_at = NOW()
             WHERE id = $6 AND user_id = $7`,
            [title, amount, date, category, note, expenseId, userId]
        );
        
        if (result.rowCount === 0) {
            return res.status(404).json({ error: 'Expense not found or access denied' });
        }
        
        console.log(`Updated personal expense ${expenseId} for user ${userId}`);
        
        res.json({ success: true });
    } catch (error) {
        console.error('Update personal expense error:', error);
        res.status(500).json({ error: 'Failed to update personal expense' });
    }
});

app.delete('/api/personal-expenses/:id', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const expenseId = req.params.id;
        
        const result = await pool.query(
            `DELETE FROM personal_expenses WHERE id = $1 AND user_id = $2`,
            [expenseId, userId]
        );
        
        if (result.rowCount === 0) {
            return res.status(404).json({ error: 'Expense not found or access denied' });
        }
        
        console.log(`Deleted personal expense ${expenseId} for user ${userId}`);
        
        res.json({ success: true });
    } catch (error) {
        console.error('Delete personal expense error:', error);
        res.status(500).json({ error: 'Failed to delete personal expense' });
    }
});

// Udhari API
app.get('/api/udhari', async (req, res) => {
    try {
        const userId = req.headers.authorization?.replace('Bearer ', '');
        
        // For development, return empty array
        res.json([]);
    } catch (error) {
        console.error('Get udhari error:', error);
        res.status(500).json({ error: 'Failed to get udhari' });
    }
});

app.post('/api/udhari', async (req, res) => {
    try {
        const userId = req.headers.authorization?.replace('Bearer ', '');
        const udhari = req.body;
        
        console.log(`Adding udhari for user ${userId}:`, udhari);
        
        res.json({ success: true, udhari });
    } catch (error) {
        console.error('Add udhari error:', error);
        res.status(500).json({ error: 'Failed to add udhari' });
    }
});

// Invites API
app.post('/api/invites', async (req, res) => {
    try {
        const userId = req.headers.authorization?.replace('Bearer ', '');
        const { friendName, friendPhone, friendEmail } = req.body;
        
        // Generate unique invite code
        const inviteCode = `INV_${Date.now()}_${Math.random().toString(36).substring(7)}`;
        
        console.log(`Creating invite for user ${userId}:`, { friendName, inviteCode });
        
        const inviteLink = `expense://invite/${inviteCode}`;
        res.json({ inviteLink, inviteCode });
    } catch (error) {
        console.error('Create invite error:', error);
        res.status(500).json({ error: 'Failed to create invite' });
    }
});

app.post('/api/invites/accept', async (req, res) => {
    try {
        const userId = req.headers.authorization?.replace('Bearer ', '');
        const { inviteCode } = req.body;
        
        console.log(`User ${userId} accepting invite:`, inviteCode);
        
        res.json({ message: 'Invite accepted successfully' });
    } catch (error) {
        console.error('Accept invite error:', error);
        res.status(500).json({ error: 'Failed to accept invite' });
    }
});

// Start server
server.listen(port, () => {
    console.log(`🚀 Expense Tracker Server running on port ${port}`);
    console.log(`📡 WebSocket server ready for real-time updates`);
    console.log(`🌐 API available at http://localhost:${port}/api`);
    console.log(`🔍 Health check: http://localhost:${port}/health`);
    
    // Test database connection if configured
    if (process.env.DATABASE_URL && process.env.DATABASE_URL !== 'your_neon_connection_string_here') {
        pool.query('SELECT NOW()', (err, result) => {
            if (err) {
                console.error('❌ Database connection failed:', err.message);
            } else {
                console.log('✅ Database connected successfully');
            }
        });
    } else {
        console.log('⚠️  Database not configured - using mock data for development');
        console.log('   Update DATABASE_URL in .env file to connect to Neon');
    }
});