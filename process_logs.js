const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand } = require('@aws-sdk/lib-dynamodb');

const client = new DynamoDBClient({});
const dynamoDB = DynamoDBDocumentClient.from(client);

exports.handler = async (event) => {
    console.log("Received event:", JSON.stringify(event, null, 2));
    
    let failedRecords = [];
    
    for (const record of event.Records) {
        try {
            // Decode base64 data from Kinesis
            const rawData = Buffer.from(record.kinesis.data, 'base64').toString();
            
            // Split the tab-separated values
            const [timestamp, ip, method, uri, status, userAgent, referer] = rawData.split('\t');
            
            if (!timestamp || !ip || !uri) {
                console.warn("Skipping invalid record:", rawData);
                continue;
            }
            
            // Convert timestamp from UNIX to ISO
            const timestampISO = new Date(parseFloat(timestamp) * 1000).toISOString();
            
            const item = {
                visitor_ip: ip,
                timestamp: timestampISO,
                path: uri,
                method: method || "UNKNOWN",
                status: parseInt(status) || 500,
                user_agent: userAgent ? decodeURIComponent(userAgent) : "UNKNOWN",
                referer: referer && referer !== '-' ? decodeURIComponent(referer) : null,
                expiration_time: Math.floor(Date.now() / 1000) + (90 * 24 * 60 * 60)
            };
            
            await dynamoDB.send(new PutCommand({
                TableName: process.env.DYNAMODB_TABLE,
                Item: item
            }));
            
            console.log('Successfully inserted:', JSON.stringify(item));
        } catch (error) {
            console.error('Error processing record:', error);
            failedRecords.push(record);
        }
    }
    
    if (failedRecords.length > 0) {
        console.error(`Failed records count: ${failedRecords.length}`);
        throw new Error(`Some records failed: ${JSON.stringify(failedRecords)}`);
    }
    
    return {
        statusCode: 200,
        body: 'Processed CloudFront logs successfully'
    };
};