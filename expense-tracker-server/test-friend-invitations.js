// Test friend invitation system

async function testFriendInvitations() {
    const baseUrl = 'http://localhost:8080';
    
    console.log('=== Testing Friend Invitation System ===');
    
    // Login with test user
    const loginResponse = await fetch(`${baseUrl}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            phone: '+919026508435',
            password: 'test123'
        })
    });
    
    const loginData = await loginResponse.json();
    console.log('✅ Logged in as:', loginData.user.name);
    
    const authHeaders = {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${loginData.token}`
    };
    
    // Test 1: Add friend by phone (create invitation)
    console.log('\n=== Test 1: Creating Friend Invitation ===');
    const inviteResponse = await fetch(`${baseUrl}/api/friends/invite`, {
        method: 'POST',
        headers: authHeaders,
        body: JSON.stringify({
            friendPhone: '+919876543210',
            friendName: 'John Doe'
        })
    });
    
    const inviteData = await inviteResponse.json();
    console.log('Invite response:', inviteData);
    
    // Test 2: Check friends list (should show pending friend)
    console.log('\n=== Test 2: Checking Friends List ===');
    const friendsResponse = await fetch(`${baseUrl}/api/friends`, {
        method: 'GET',
        headers: authHeaders
    });
    
    const friendsData = await friendsResponse.json();
    console.log('Friends list:', friendsData);
    
    // Test 3: Check pending invitations (for the invited phone number)
    // Note: This would normally be called by the user with phone +919876543210
    console.log('\n=== Test 3: Simulating Invited User Login ===');
    
    // Register the invited user
    const registerResponse = await fetch(`${baseUrl}/auth/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            phone: '+919876543210',
            password: 'test123',
            name: 'John Doe',
            email: 'john@example.com'
        })
    });
    
    const registerData = await registerResponse.json();
    console.log('Registration result:', registerData.success ? 'Success' : registerData.message);
    
    if (registerData.token) {
        const johnAuthHeaders = {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${registerData.token}`
        };
        
        // Check pending invitations for John
        const pendingResponse = await fetch(`${baseUrl}/api/friends/pending`, {
            method: 'GET',
            headers: johnAuthHeaders
        });
        
        const pendingData = await pendingResponse.json();
        console.log('Pending invitations for John:', pendingData);
        
        // Accept the invitation
        if (pendingData.length > 0) {
            const acceptResponse = await fetch(`${baseUrl}/api/friends/accept`, {
                method: 'POST',
                headers: johnAuthHeaders,
                body: JSON.stringify({
                    invitationId: pendingData[0].id
                })
            });
            
            const acceptData = await acceptResponse.json();
            console.log('Accept invitation result:', acceptData);
            
            // Check John's friends list
            const johnFriendsResponse = await fetch(`${baseUrl}/api/friends`, {
                method: 'GET',
                headers: johnAuthHeaders
            });
            
            const johnFriendsData = await johnFriendsResponse.json();
            console.log("John's friends list:", johnFriendsData);
            
            // Check original user's friends list again
            const updatedFriendsResponse = await fetch(`${baseUrl}/api/friends`, {
                method: 'GET',
                headers: authHeaders
            });
            
            const updatedFriendsData = await updatedFriendsResponse.json();
            console.log("Test User's updated friends list:", updatedFriendsData);
        }
    }
    
    console.log('\n✅ Friend invitation system test completed!');
}

testFriendInvitations().catch(console.error);