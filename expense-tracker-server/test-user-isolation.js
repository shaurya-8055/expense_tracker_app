// Test the API endpoints to ensure user data isolation is working

// Test user 1 (using our test user credentials)
async function testUserDataIsolation() {
    const baseUrl = 'http://localhost:8080';
    
    // Test authentication endpoints first
    console.log('=== Testing Authentication ===');
    
    // Test login with our test user
    const loginResponse = await fetch(`${baseUrl}/auth/login`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            phone: '+919026508435',
            password: 'test123'
        })
    });
    
    const loginData = await loginResponse.json();
    console.log('Login response:', loginData);
    
    if (!loginData.token) {
        console.error('Login failed, cannot test user isolation');
        return;
    }
    
    const authToken = loginData.token;
    const authHeaders = {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${authToken}`
    };
    
    console.log('\n=== Testing Personal Expenses ===');
    
    // Test adding a personal expense
    const addExpenseResponse = await fetch(`${baseUrl}/api/personal-expenses`, {
        method: 'POST',
        headers: authHeaders,
        body: JSON.stringify({
            id: `expense_${Date.now()}`,
            title: 'Test Lunch',
            amount: 25.50,
            date: new Date().toISOString(),
            category: 0, // Food category
            note: 'Test expense for user isolation'
        })
    });
    
    const addExpenseData = await addExpenseResponse.json();
    console.log('Add expense response:', addExpenseData);
    
    // Test getting personal expenses
    const getExpensesResponse = await fetch(`${baseUrl}/api/personal-expenses`, {
        method: 'GET',
        headers: authHeaders
    });
    
    const expensesData = await getExpensesResponse.json();
    console.log('Get expenses response:', expensesData);
    
    console.log('\n=== Testing Friends API ===');
    
    // Test adding a friend
    const addFriendResponse = await fetch(`${baseUrl}/api/friends`, {
        method: 'POST',
        headers: authHeaders,
        body: JSON.stringify({
            id: `friend_${Date.now()}`,
            name: 'Test Friend',
            phoneNumber: '+91999999999',
            email: 'testfriend@example.com'
        })
    });
    
    const addFriendData = await addFriendResponse.json();
    console.log('Add friend response:', addFriendData);
    
    // Test getting friends
    const getFriendsResponse = await fetch(`${baseUrl}/api/friends`, {
        method: 'GET',
        headers: authHeaders
    });
    
    const friendsData = await getFriendsResponse.json();
    console.log('Get friends response:', friendsData);
    
    console.log('\n=== Testing Contact Integration ===');
    
    // Test checking if a user exists
    const checkUserResponse = await fetch(`${baseUrl}/api/users/check`, {
        method: 'POST',
        headers: authHeaders,
        body: JSON.stringify({
            phone: '+919026508435'
        })
    });
    
    const checkUserData = await checkUserResponse.json();
    console.log('Check user response:', checkUserData);
    
    console.log('\n=== Test Complete ===');
}

// Run the test
testUserDataIsolation().catch(console.error);