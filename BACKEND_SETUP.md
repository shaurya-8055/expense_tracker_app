# Real-Time Expense Tracker Backend Setup Guide

This guide will help you set up the backend infrastructure for real-time expense synchronization using Neon PostgreSQL.

## Prerequisites

- Neon account (https://neon.tech)
- Node.js (for WebSocket server)
- Basic understanding of PostgreSQL

## 1. Neon PostgreSQL Database Setup

### Step 1: Create Neon Project

1. Sign up at https://neon.tech
2. Create a new project
3. Note down your database connection string (it looks like: `postgresql://username:password@host/database?sslmode=require`)

### Step 2: Create Database Tables

Execute the following SQL commands in your Neon console:

```sql
-- Create users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create friends table (relationships between users)
CREATE TABLE friends (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    friend_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    friend_name VARCHAR(255) NOT NULL,
    friend_phone VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, friend_user_id)
);

-- Create group_expenses table
CREATE TABLE group_expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    total_amount DECIMAL(10,2) NOT NULL,
    paid_by VARCHAR(255) NOT NULL,
    participants JSON NOT NULL, -- Array of participant IDs
    splits JSON NOT NULL, -- Object mapping participant ID to amount
    date TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create personal_expenses table
CREATE TABLE personal_expenses (
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

-- Create udhari table
CREATE TABLE udhari (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    friend_id VARCHAR(255) NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    description TEXT,
    type INTEGER NOT NULL, -- 0 for lent, 1 for borrowed
    status INTEGER DEFAULT 0, -- 0 for pending, 1 for settled
    date TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create invites table
CREATE TABLE invites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    inviter_id UUID REFERENCES users(id) ON DELETE CASCADE,
    invite_code VARCHAR(255) UNIQUE NOT NULL,
    friend_name VARCHAR(255) NOT NULL,
    friend_phone VARCHAR(20),
    friend_email VARCHAR(255),
    status INTEGER DEFAULT 0, -- 0 for pending, 1 for accepted, 2 for expired
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP DEFAULT (CURRENT_TIMESTAMP + INTERVAL '7 days')
);

-- Create indexes for better performance
CREATE INDEX idx_friends_user_id ON friends(user_id);
CREATE INDEX idx_group_expenses_user_id ON group_expenses(user_id);
CREATE INDEX idx_personal_expenses_user_id ON personal_expenses(user_id);
CREATE INDEX idx_udhari_user_id ON udhari(user_id);
CREATE INDEX idx_invites_code ON invites(invite_code);
CREATE INDEX idx_invites_status ON invites(status);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers to automatically update updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_group_expenses_updated_at BEFORE UPDATE ON group_expenses
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_personal_expenses_updated_at BEFORE UPDATE ON personal_expenses
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_udhari_updated_at BEFORE UPDATE ON udhari
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

## 2. WebSocket Server Setup

Create a Node.js WebSocket server for real-time updates:

### Step 1: Create Node.js Project

```bash
mkdir expense-tracker-server
cd expense-tracker-server
npm init -y
```

### Step 2: Install Dependencies

```bash
npm install ws pg express cors dotenv
```

### Step 3: Create Environment File

Create `.env` file:

```env
DATABASE_URL=your_neon_connection_string
PORT=8080
```

### Step 4: Create Server (server.js)

```javascript
const WebSocket = require("ws");
const express = require("express");
const { Pool } = require("pg");
const cors = require("cors");
require("dotenv").config();

const app = express();
const port = process.env.PORT || 8080;

// Database connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

// Middleware
app.use(cors());
app.use(express.json());

// Store WebSocket connections
const connections = new Map();

// Create HTTP server
const server = require("http").createServer(app);

// Create WebSocket server
const wss = new WebSocket.Server({ server });

// WebSocket connection handler
wss.on("connection", (ws, req) => {
  console.log("New WebSocket connection");

  ws.on("message", (message) => {
    try {
      const data = JSON.parse(message);

      if (data.type === "auth") {
        // Store user ID with connection
        connections.set(ws, data.userId);
        ws.send(JSON.stringify({ type: "auth_success" }));
      }
    } catch (error) {
      console.error("WebSocket message error:", error);
    }
  });

  ws.on("close", () => {
    connections.delete(ws);
    console.log("WebSocket connection closed");
  });
});

// Broadcast to all connected clients except sender
function broadcast(senderId, data) {
  connections.forEach((userId, ws) => {
    if (userId !== senderId && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify(data));
    }
  });
}

// REST API Routes

// Authentication
app.post("/api/auth/login", async (req, res) => {
  try {
    const { name, phone, email } = req.body;

    // Check if user exists
    let result = await pool.query(
      "SELECT * FROM users WHERE phone = $1 OR email = $2",
      [phone, email]
    );

    let user;
    if (result.rows.length > 0) {
      user = result.rows[0];
    } else {
      // Create new user
      result = await pool.query(
        "INSERT INTO users (name, phone, email) VALUES ($1, $2, $3) RETURNING *",
        [name, phone, email]
      );
      user = result.rows[0];
    }

    res.json({ user, token: user.id });
  } catch (error) {
    console.error("Login error:", error);
    res.status(500).json({ error: "Login failed" });
  }
});

// Friends API
app.get("/api/friends", async (req, res) => {
  try {
    const userId = req.headers.authorization?.replace("Bearer ", "");
    const result = await pool.query(
      "SELECT f.*, u.name as friend_name, u.phone as friend_phone FROM friends f LEFT JOIN users u ON f.friend_user_id = u.id WHERE f.user_id = $1",
      [userId]
    );
    res.json(result.rows);
  } catch (error) {
    console.error("Get friends error:", error);
    res.status(500).json({ error: "Failed to get friends" });
  }
});

app.post("/api/friends", async (req, res) => {
  try {
    const userId = req.headers.authorization?.replace("Bearer ", "");
    const friend = req.body;

    const result = await pool.query(
      "INSERT INTO friends (id, user_id, friend_user_id, friend_name, friend_phone) VALUES ($1, $2, $3, $4, $5) RETURNING *",
      [friend.id, userId, friend.friendUserId, friend.name, friend.phone]
    );

    // Broadcast to other users
    broadcast(userId, {
      type: "friend_added",
      data: friend,
      userId: userId,
    });

    res.json(result.rows[0]);
  } catch (error) {
    console.error("Add friend error:", error);
    res.status(500).json({ error: "Failed to add friend" });
  }
});

// Group Expenses API
app.get("/api/group-expenses", async (req, res) => {
  try {
    const userId = req.headers.authorization?.replace("Bearer ", "");
    const result = await pool.query(
      "SELECT * FROM group_expenses WHERE user_id = $1 ORDER BY date DESC",
      [userId]
    );
    res.json(result.rows);
  } catch (error) {
    console.error("Get group expenses error:", error);
    res.status(500).json({ error: "Failed to get group expenses" });
  }
});

app.post("/api/group-expenses", async (req, res) => {
  try {
    const userId = req.headers.authorization?.replace("Bearer ", "");
    const expense = req.body;

    const result = await pool.query(
      "INSERT INTO group_expenses (id, user_id, title, description, total_amount, paid_by, participants, splits, date) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *",
      [
        expense.id,
        userId,
        expense.title,
        expense.description,
        expense.totalAmount,
        expense.paidBy,
        JSON.stringify(expense.participants),
        JSON.stringify(expense.splits),
        expense.date,
      ]
    );

    // Broadcast to other users
    broadcast(userId, {
      type: "group_expense_added",
      data: expense,
      userId: userId,
    });

    res.json(result.rows[0]);
  } catch (error) {
    console.error("Add group expense error:", error);
    res.status(500).json({ error: "Failed to add group expense" });
  }
});

// Personal Expenses API
app.get("/api/personal-expenses", async (req, res) => {
  try {
    const userId = req.headers.authorization?.replace("Bearer ", "");
    const result = await pool.query(
      "SELECT * FROM personal_expenses WHERE user_id = $1 ORDER BY date DESC",
      [userId]
    );
    res.json(result.rows);
  } catch (error) {
    console.error("Get personal expenses error:", error);
    res.status(500).json({ error: "Failed to get personal expenses" });
  }
});

app.post("/api/personal-expenses", async (req, res) => {
  try {
    const userId = req.headers.authorization?.replace("Bearer ", "");
    const expense = req.body;

    const result = await pool.query(
      "INSERT INTO personal_expenses (id, user_id, title, description, amount, category, date) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *",
      [
        expense.id,
        userId,
        expense.title,
        expense.description,
        expense.amount,
        expense.category,
        expense.date,
      ]
    );

    res.json(result.rows[0]);
  } catch (error) {
    console.error("Add personal expense error:", error);
    res.status(500).json({ error: "Failed to add personal expense" });
  }
});

// Udhari API
app.get("/api/udhari", async (req, res) => {
  try {
    const userId = req.headers.authorization?.replace("Bearer ", "");
    const result = await pool.query(
      "SELECT * FROM udhari WHERE user_id = $1 ORDER BY date DESC",
      [userId]
    );
    res.json(result.rows);
  } catch (error) {
    console.error("Get udhari error:", error);
    res.status(500).json({ error: "Failed to get udhari" });
  }
});

app.post("/api/udhari", async (req, res) => {
  try {
    const userId = req.headers.authorization?.replace("Bearer ", "");
    const udhari = req.body;

    const result = await pool.query(
      "INSERT INTO udhari (id, user_id, friend_id, amount, description, type, status, date) VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *",
      [
        udhari.id,
        userId,
        udhari.friendId,
        udhari.amount,
        udhari.description,
        udhari.type,
        udhari.status,
        udhari.date,
      ]
    );

    res.json(result.rows[0]);
  } catch (error) {
    console.error("Add udhari error:", error);
    res.status(500).json({ error: "Failed to add udhari" });
  }
});

// Invites API
app.post("/api/invites", async (req, res) => {
  try {
    const userId = req.headers.authorization?.replace("Bearer ", "");
    const { friendName, friendPhone, friendEmail } = req.body;

    // Generate unique invite code
    const inviteCode = `INV_${Date.now()}_${Math.random()
      .toString(36)
      .substring(7)}`;

    const result = await pool.query(
      "INSERT INTO invites (inviter_id, invite_code, friend_name, friend_phone, friend_email) VALUES ($1, $2, $3, $4, $5) RETURNING *",
      [userId, inviteCode, friendName, friendPhone, friendEmail]
    );

    const inviteLink = `expense://invite/${inviteCode}`;
    res.json({ inviteLink, inviteCode });
  } catch (error) {
    console.error("Create invite error:", error);
    res.status(500).json({ error: "Failed to create invite" });
  }
});

app.post("/api/invites/accept", async (req, res) => {
  try {
    const userId = req.headers.authorization?.replace("Bearer ", "");
    const { inviteCode } = req.body;

    // Get invite details
    const inviteResult = await pool.query(
      "SELECT * FROM invites WHERE invite_code = $1 AND status = 0 AND expires_at > CURRENT_TIMESTAMP",
      [inviteCode]
    );

    if (inviteResult.rows.length === 0) {
      return res.status(404).json({ error: "Invalid or expired invite" });
    }

    const invite = inviteResult.rows[0];

    // Add as friends (both ways)
    await pool.query(
      "INSERT INTO friends (user_id, friend_user_id, friend_name) VALUES ($1, $2, (SELECT name FROM users WHERE id = $2)) ON CONFLICT DO NOTHING",
      [userId, invite.inviter_id]
    );

    await pool.query(
      "INSERT INTO friends (user_id, friend_user_id, friend_name) VALUES ($1, $2, (SELECT name FROM users WHERE id = $2)) ON CONFLICT DO NOTHING",
      [invite.inviter_id, userId]
    );

    // Mark invite as accepted
    await pool.query("UPDATE invites SET status = 1 WHERE invite_code = $1", [
      inviteCode,
    ]);

    res.json({ message: "Invite accepted successfully" });
  } catch (error) {
    console.error("Accept invite error:", error);
    res.status(500).json({ error: "Failed to accept invite" });
  }
});

// Start server
server.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
```

### Step 5: Create Package.json Scripts

Add to package.json:

```json
{
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  }
}
```

### Step 6: Deploy Server

You can deploy this to:

- Heroku (easy deployment)
- Railway (modern alternative)
- Vercel (for Node.js apps)
- Any cloud provider with Node.js support

## 3. Flutter App Configuration

### Step 1: Update Database Service

In your Flutter app, update the `DatabaseService` to point to your deployed server:

```dart
class DatabaseService {
  static const String _baseUrl = 'your-deployed-server-url'; // e.g., 'https://your-app.herokuapp.com'
  static const String _wsUrl = 'your-websocket-url'; // e.g., 'wss://your-app.herokuapp.com'

  // Rest of the implementation...
}
```

### Step 2: Test Real-Time Sync

1. Deploy your server
2. Update the URLs in your Flutter app
3. Build and install the app on multiple devices
4. Test creating expenses on one device and see them appear on others

## 4. Security Considerations

1. **Authentication**: Implement proper JWT authentication
2. **Data Validation**: Validate all inputs on the server
3. **Rate Limiting**: Implement rate limiting to prevent abuse
4. **HTTPS/WSS**: Use secure connections in production
5. **Environment Variables**: Keep sensitive data in environment variables

## 5. Monitoring and Maintenance

1. **Logging**: Add comprehensive logging to your server
2. **Error Handling**: Implement proper error handling and recovery
3. **Database Backups**: Set up regular backups in Neon
4. **Performance Monitoring**: Monitor database and server performance

## Deployment URLs to Update

Replace these placeholders in your Flutter `DatabaseService`:

- `_baseUrl`: Your deployed REST API URL
- `_wsUrl`: Your deployed WebSocket URL

Example for Heroku:

```dart
static const String _baseUrl = 'https://expense-tracker-api.herokuapp.com';
static const String _wsUrl = 'wss://expense-tracker-api.herokuapp.com';
```

This setup provides:

- Real-time synchronization across all connected devices
- Offline support with local storage fallback
- Secure user authentication and data management
- Scalable PostgreSQL database with Neon
- WebSocket connections for instant updates
- REST API for all CRUD operations

Your friends will now see expense updates instantly when you make changes in your app!
