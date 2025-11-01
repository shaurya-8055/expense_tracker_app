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
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';

// Authentication middleware
const authenticateToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
        return res.status(401).json({ message: 'Access token required' });
    }

    jwt.verify(token, JWT_SECRET, (err, decoded) => {
        if (err) {
            return res.status(403).json({ message: 'Invalid or expired token' });
        }
        req.userId = decoded.userId;
        next();
    });
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
        
        // Check if user already exists
        if (usersByPhone.has(phone)) {
            return res.status(400).json({ message: 'User with this phone number already exists' });
        }
        
        // Hash password
        const saltRounds = 10;
        const hashedPassword = await bcrypt.hash(password, saltRounds);
        
        // Create new user
        const userId = `user_${Date.now()}_${Math.random().toString(36).substring(7)}`;
        const user = { 
            id: userId, 
            name, 
            phone, 
            email: email || null, 
            password: hashedPassword,
            createdAt: new Date(),
            updatedAt: new Date()
        };
        
        users.set(userId, user);
        usersByPhone.set(phone, user);
        
        // Generate JWT token
        const token = jwt.sign({ userId, phone }, JWT_SECRET, { expiresIn: '30d' });
        
        // Return user data without password
        const userResponse = { ...user };
        delete userResponse.password;
        
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
        
        // Check if user exists
        const user = usersByPhone.get(phone);
        if (!user) {
            return res.status(401).json({ message: 'Invalid phone number or password' });
        }
        
        // Verify password
        const isValidPassword = await bcrypt.compare(password, user.password);
        if (!isValidPassword) {
            return res.status(401).json({ message: 'Invalid phone number or password' });
        }
        
        // Generate JWT token
        const token = jwt.sign({ userId: user.id, phone }, JWT_SECRET, { expiresIn: '30d' });
        
        // Return user data without password
        const userResponse = { ...user };
        delete userResponse.password;
        
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
        const user = users.get(req.userId);
        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }
        
        // Return user data without password
        const userResponse = { ...user };
        delete userResponse.password;
        
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
        const user = users.get(req.userId);
        
        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }
        
        // Update user data
        if (name) user.name = name;
        if (email !== undefined) user.email = email;
        user.updatedAt = new Date();
        
        users.set(req.userId, user);
        
        // Return updated user data without password
        const userResponse = { ...user };
        delete userResponse.password;
        
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
        const user = users.get(req.userId);
        
        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }
        
        // Verify current password
        const isValidPassword = await bcrypt.compare(currentPassword, user.password);
        if (!isValidPassword) {
            return res.status(401).json({ message: 'Current password is incorrect' });
        }
        
        // Hash new password
        const saltRounds = 10;
        const hashedPassword = await bcrypt.hash(newPassword, saltRounds);
        
        // Update password
        user.password = hashedPassword;
        user.updatedAt = new Date();
        users.set(req.userId, user);
        
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
        const exists = usersByPhone.has(phone);
        
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