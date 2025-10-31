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

// In-memory user storage for development
const users = new Map();
const usersByPhone = new Map();

// REST API Routes

// Authentication
app.post('/api/auth/login', async (req, res) => {
    try {
        const { name, phone, email } = req.body;
        
        // Check if user exists by phone
        let user = usersByPhone.get(phone);
        
        if (!user) {
            // Create new user
            const userId = `user_${Date.now()}_${Math.random().toString(36).substring(7)}`;
            user = { id: userId, name, phone, email, createdAt: new Date() };
            users.set(userId, user);
            usersByPhone.set(phone, user);
            console.log(`New user registered: ${name} (${phone})`);
        } else {
            console.log(`Existing user login: ${user.name} (${phone})`);
        }
        
        res.json({ 
            user: user, 
            token: user.id 
        });
    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({ error: 'Login failed' });
    }
});

// User management endpoints for contact integration
app.post('/api/users/check', async (req, res) => {
    try {
        const { phone } = req.body;
        const exists = usersByPhone.has(phone);
        
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
        const user = usersByPhone.get(phone);
        
        if (user) {
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

app.post('/api/users/search', async (req, res) => {
    try {
        const { query } = req.body;
        const currentUserId = req.headers.authorization?.replace('Bearer ', '');
        
        const results = Array.from(users.values()).filter(user => {
            // Don't include current user in search results
            if (user.id === currentUserId) return false;
            
            const lowerQuery = query.toLowerCase();
            return user.name.toLowerCase().includes(lowerQuery) ||
                   user.phone.includes(query) ||
                   (user.email && user.email.toLowerCase().includes(lowerQuery));
        });
        
        console.log(`Search for "${query}" returned ${results.length} results`);
        res.json({ users: results });
    } catch (error) {
        console.error('Search users error:', error);
        res.status(500).json({ error: 'Failed to search users' });
    }
});

// Friends API
app.get('/api/friends', async (req, res) => {
    try {
        const userId = req.headers.authorization?.replace('Bearer ', '');
        
        // For development, return mock data
        // In production, this would query your database
        res.json([
            {
                id: 'friend_1',
                name: 'John Doe',
                phone: '+1234567890',
                email: 'john@example.com'
            },
            {
                id: 'friend_2', 
                name: 'Jane Smith',
                phone: '+1234567891',
                email: 'jane@example.com'
            }
        ]);
    } catch (error) {
        console.error('Get friends error:', error);
        res.status(500).json({ error: 'Failed to get friends' });
    }
});

app.post('/api/friends', async (req, res) => {
    try {
        const userId = req.headers.authorization?.replace('Bearer ', '');
        const friend = req.body;
        
        console.log(`Adding friend for user ${userId}:`, friend);
        
        // Broadcast to other users
        broadcast(userId, {
            type: 'friend_added',
            data: friend,
            userId: userId
        });
        
        res.json({ success: true, friend });
    } catch (error) {
        console.error('Add friend error:', error);
        res.status(500).json({ error: 'Failed to add friend' });
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
app.get('/api/personal-expenses', async (req, res) => {
    try {
        const userId = req.headers.authorization?.replace('Bearer ', '');
        
        // For development, return empty array
        res.json([]);
    } catch (error) {
        console.error('Get personal expenses error:', error);
        res.status(500).json({ error: 'Failed to get personal expenses' });
    }
});

app.post('/api/personal-expenses', async (req, res) => {
    try {
        const userId = req.headers.authorization?.replace('Bearer ', '');
        const expense = req.body;
        
        console.log(`Adding personal expense for user ${userId}:`, expense);
        
        res.json({ success: true, expense });
    } catch (error) {
        console.error('Add personal expense error:', error);
        res.status(500).json({ error: 'Failed to add personal expense' });
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