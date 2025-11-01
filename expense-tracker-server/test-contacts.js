// Debug contacts functionality

async function testContactsPermission() {
    try {
        console.log('🔍 Testing contact permission and fetching...');
        
        // Simulate Android environment for testing
        const mockContacts = [
            {
                id: '1',
                displayName: 'John Doe',
                phones: [{ number: '+919876543210' }],
                emails: [{ address: 'john@example.com' }]
            },
            {
                id: '2', 
                displayName: 'Jane Smith',
                phones: [{ number: '+919876543211' }],
                emails: [{ address: 'jane@example.com' }]
            },
            {
                id: '3',
                displayName: 'Test User',
                phones: [{ number: '+919026508435' }], // Our registered user
                emails: [{ address: 'test@example.com' }]
            }
        ];
        
        console.log('Mock contacts:', mockContacts.length);
        
        // Test phone number cleaning
        function cleanPhoneNumber(phone) {
            let cleaned = phone.replace(/[^\d+]/g, '');
            
            if (cleaned.startsWith('0')) {
                cleaned = '+91' + cleaned.substring(1);
            } else if (cleaned.startsWith('+91') && cleaned.length === 13) {
                return cleaned;
            } else if (cleaned.length === 10) {
                cleaned = '+91' + cleaned;
            }
            
            return cleaned;
        }
        
        // Test API calls for each contact
        for (const contact of mockContacts) {
            const phone = cleanPhoneNumber(contact.phones[0].number);
            console.log(`\nTesting ${contact.displayName} (${phone}):`);
            
            try {
                const checkResponse = await fetch('http://localhost:8080/api/users/check', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ phone })
                });
                
                const checkResult = await checkResponse.json();
                console.log('  User exists:', checkResult.exists);
                
                if (checkResult.exists) {
                    const userResponse = await fetch('http://localhost:8080/api/users/by-phone', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ phone })
                    });
                    
                    if (userResponse.ok) {
                        const userData = await userResponse.json();
                        console.log('  User data:', userData.user);
                    }
                }
            } catch (error) {
                console.log('  Error:', error.message);
            }
        }
        
    } catch (error) {
        console.error('❌ Contact test failed:', error);
    }
}

testContactsPermission().catch(console.error);