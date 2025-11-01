// Test shared expenses with friend invitations

async function testSharedExpenses() {
    const baseUrl = 'http://localhost:8080';
    
    console.log('=== Testing Shared Expenses System ===');
    
    // Login with Test User
    const loginResponse1 = await fetch(`${baseUrl}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            phone: '+919026508435',
            password: 'test123'
        })
    });
    
    const loginData1 = await loginResponse1.json();
    console.log('✅ Logged in as Test User:', loginData1.user.name);
    
    const testUserHeaders = {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${loginData1.token}`
    };
    
    // Login with John (the friend)
    const loginResponse2 = await fetch(`${baseUrl}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            phone: '+919876543210',
            password: 'test123'
        })
    });
    
    const loginData2 = await loginResponse2.json();
    console.log('✅ Logged in as John:', loginData2.user.name);
    
    const johnHeaders = {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${loginData2.token}`
    };
    
    // Test User creates a shared expense
    console.log('\n=== Test User Creating Shared Expense ===');
    const expenseResponse = await fetch(`${baseUrl}/api/expenses`, {
        method: 'POST',
        headers: testUserHeaders,
        body: JSON.stringify({
            description: 'Dinner at restaurant',
            amount: 2000,
            category: 'Food',
            type: 'shared',
            sharedWith: [
                {
                    friendId: 'friend_1761980089420', // John's friend ID from previous test
                    amount: 1000
                }
            ]
        })
    });
    
    const expenseData = await expenseResponse.json();
    console.log('Shared expense created:', expenseData);
    
    // Check Test User's shared expenses
    console.log('\n=== Test User\'s Shared Expenses ===');
    const testUserSharedResponse = await fetch(`${baseUrl}/api/expenses/shared`, {
        method: 'GET',
        headers: testUserHeaders
    });
    
    const testUserSharedData = await testUserSharedResponse.json();
    console.log('Test User shared expenses:', testUserSharedData);
    
    // Check John's shared expenses
    console.log('\n=== John\'s Shared Expenses ===');
    const johnSharedResponse = await fetch(`${baseUrl}/api/expenses/shared`, {
        method: 'GET',
        headers: johnHeaders
    });
    
    const johnSharedData = await johnSharedResponse.json();
    console.log('John shared expenses:', johnSharedData);
    
    // Check both users' regular expenses
    console.log('\n=== Test User\'s All Expenses ===');
    const testUserAllResponse = await fetch(`${baseUrl}/api/expenses`, {
        method: 'GET',
        headers: testUserHeaders
    });
    
    const testUserAllData = await testUserAllResponse.json();
    console.log('Test User all expenses:', Array.isArray(testUserAllData) ? testUserAllData.slice(0, 3) : testUserAllData); // Show first 3
    
    console.log('\n=== John\'s All Expenses ===');
    const johnAllResponse = await fetch(`${baseUrl}/api/expenses`, {
        method: 'GET',
        headers: johnHeaders
    });
    
    const johnAllData = await johnAllResponse.json();
    console.log('John all expenses:', johnAllData);
    
    console.log('\n✅ Shared expenses system test completed!');
}

testSharedExpenses().catch(console.error);