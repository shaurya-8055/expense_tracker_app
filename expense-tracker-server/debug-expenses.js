// Debug personal expenses API

async function testPersonalExpensesDebug() {
    const baseUrl = 'http://localhost:8080';
    
    // Login first
    const loginResponse = await fetch(`${baseUrl}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            phone: '+919026508435',
            password: 'test123'
        })
    });
    
    const loginData = await loginResponse.json();
    console.log('Login successful, user ID:', loginData.user.id);
    
    const authHeaders = {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${loginData.token}`
    };
    
    // Test adding expense with detailed error logging
    console.log('\n=== Testing Add Personal Expense ===');
    const expenseData = {
        id: `expense_${Date.now()}`,
        title: 'Debug Test Lunch',
        amount: 15.75,
        date: new Date().toISOString(),
        category: 0,
        note: 'Debug test expense'
    };
    
    console.log('Sending expense data:', expenseData);
    
    const addResponse = await fetch(`${baseUrl}/api/personal-expenses`, {
        method: 'POST',
        headers: authHeaders,
        body: JSON.stringify(expenseData)
    });
    
    console.log('Response status:', addResponse.status);
    console.log('Response headers:', Object.fromEntries(addResponse.headers.entries()));
    
    const responseText = await addResponse.text();
    console.log('Raw response:', responseText);
    
    try {
        const responseJson = JSON.parse(responseText);
        console.log('Parsed response:', responseJson);
    } catch (e) {
        console.log('Could not parse as JSON');
    }
}

testPersonalExpensesDebug().catch(console.error);