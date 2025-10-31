-- Run this SQL in your Neon database console

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