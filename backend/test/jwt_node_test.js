const jwt = require('jsonwebtoken');

const JWT_SECRET = 'here4help_jwt_secret_key_2025_development';
const token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoyLCJlbWFpbCI6InRlc3RAZXhhbXBsZS5jb20iLCJuYW1lIjoiVGVzdCBVc2VyIiwiaWF0IjoxNzU1ODgxOTgyLCJleHAiOjE3NTU4ODU1ODIsIm5iZiI6MTc1NTg4MTk4Mn0.89bzPjzMcfhraJagbgLv_IL2zkD3AdinnHpHIuzNF_s';

console.log('🔐 Node.js JWT 驗證測試');
console.log('JWT_SECRET:', JWT_SECRET.substring(0, 10) + '...');
console.log('Token:', token.substring(0, 50) + '...');

try {
    const payload = jwt.verify(token, JWT_SECRET, {
        algorithms: ['HS256'],
        ignoreExpiration: false,
        ignoreNotBefore: false
    });
    
    console.log('✅ Node.js JWT 驗證成功');
    console.log('Payload:', JSON.stringify(payload, null, 2));
} catch (error) {
    console.log('❌ Node.js JWT 驗證失敗:', error.name, error.message);
    
    // 嘗試手動驗證
    console.log('\n🔍 手動驗證:');
    const parts = token.split('.');
    if (parts.length === 3) {
        const header = JSON.parse(Buffer.from(parts[0], 'base64url').toString());
        const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString());
        
        console.log('Header:', JSON.stringify(header));
        console.log('Payload:', JSON.stringify(payload));
        
        // 重新計算簽名
        const crypto = require('crypto');
        const expectedSignature = crypto
            .createHmac('sha256', JWT_SECRET)
            .update(parts[0] + '.' + parts[1])
            .digest('base64url');
            
        console.log('期望簽名:', expectedSignature);
        console.log('實際簽名:', parts[2]);
        console.log('簽名匹配:', expectedSignature === parts[2]);
    }
}