# ETL Job Examples

This directory contains two complete ETL (Extract, Transform, Load) job implementations demonstrating the same functionality using different technologies:

1. **IBM Java SDK Core ETL** - A standalone Java application using IBM Java SDK Core
2. **SnapLogic ETL Snap** - A custom SnapLogic snap for the SnapLogic platform

## Overview

Both implementations demonstrate a production-ready customer data ETL pipeline that:
- **Extracts** customer data from a source REST API
- **Transforms** the data (validation, normalization, enrichment)
- **Loads** the data to a target REST API in batches

## Project Structure

```
etl-examples/
├── README.md                          # This file
├── ibm-java-sdk-etl/                  # IBM Java SDK Core implementation
│   ├── README.md                      # Detailed documentation
│   ├── pom.xml                        # Maven configuration
│   └── src/main/java/com/example/etl/
│       ├── CustomerDataETL.java       # Main orchestrator
│       ├── DataExtractor.java         # Extract phase
│       ├── DataTransformer.java       # Transform phase
│       ├── DataLoader.java            # Load phase
│       └── CustomerRecord.java        # Data model
└── snaplogic-etl/                     # SnapLogic snap implementation
    ├── README.md                      # Detailed documentation
    ├── pom.xml                        # Maven configuration
    └── src/main/java/com/snaplogic/snaps/customeretl/
        ├── CustomerETLSnap.java       # Main snap component
        └── CustomerRecord.java        # Data model
```

## Quick Start

### IBM Java SDK Core ETL

```bash
cd ibm-java-sdk-etl
mvn clean install
java -jar target/ibm-java-sdk-etl-1.0.0.jar
```

See [ibm-java-sdk-etl/README.md](ibm-java-sdk-etl/README.md) for detailed instructions.

### SnapLogic ETL Snap

```bash
cd snaplogic-etl
mvn clean install -DskipTests -DVERSION=1 -Dsl_build=0001
# Upload target/customer-etl-snap-1.0.0.jar to SnapLogic
```

See [snaplogic-etl/README.md](snaplogic-etl/README.md) for detailed instructions.

## Feature Comparison

| Feature | IBM Java SDK Core | SnapLogic Snap |
|---------|-------------------|----------------|
| **Deployment** | Standalone JAR | SnapLogic Platform |
| **Configuration** | Environment variables | Snap properties UI |
| **Authentication** | IAM, Basic Auth | Basic Auth, API Key |
| **Batch Processing** | ✓ | ✓ |
| **Data Validation** | ✓ | ✓ |
| **Data Normalization** | ✓ | ✓ |
| **Data Enrichment** | ✓ | ✓ |
| **Error Handling** | ✓ | ✓ |
| **Logging** | SLF4J | SLF4J |
| **Mock Data** | ✓ | ✓ |
| **Scheduling** | External | Built-in |
| **Monitoring** | Custom | SnapLogic Dashboard |
| **Scalability** | Manual | Snaplex Auto-scaling |

## ETL Process Flow

Both implementations follow the same ETL process:

### 1. Extract Phase
```
Source API → Authenticate → HTTP GET → Parse JSON → CustomerRecord List
```

### 2. Transform Phase
```
Raw Records → Validate → Normalize → Enrich → Clean Records
```

**Validation Rules:**
- Required: Customer ID, Email, First Name, Last Name
- Email format validation
- Invalid records are filtered out

**Normalization:**
- Name capitalization (First letter uppercase)
- Email lowercase
- Phone number formatting (XXX-XXX-XXXX)
- State/Country code uppercase
- Status lowercase

**Enrichment:**
- Default status: "active"
- Default country: "USA"
- Default total purchases: 0.0

### 3. Load Phase
```
Clean Records → Batch (100 records) → HTTP POST → Target API
```

## Data Model

Both implementations use the same CustomerRecord data model:

```java
public class CustomerRecord {
    private String customerId;      // Required
    private String firstName;       // Required
    private String lastName;        // Required
    private String email;           // Required (validated)
    private String phone;           // Optional
    private String address;         // Optional
    private String city;            // Optional
    private String state;           // Optional
    private String zipCode;         // Optional
    private String country;         // Optional (default: USA)
    private String status;          // Optional (default: active)
    private Double totalPurchases;  // Optional (default: 0.0)
}
```

## Authentication Support

### IBM Java SDK Core ETL
- **IAM Authentication**: Using IBM Cloud API keys
- **Basic Authentication**: Username/password
- **No Authentication**: For testing

### SnapLogic ETL Snap
- **API Key Authentication**: Bearer token
- **Basic Authentication**: Username/password
- **No Authentication**: For public APIs

## Configuration

### IBM Java SDK Core ETL

Configure via environment variables:

```bash
export SOURCE_API_URL="https://api.example.com/customers"
export TARGET_API_URL="https://warehouse.example.com/customers"
export SOURCE_API_KEY="your-source-api-key"
export TARGET_API_KEY="your-target-api-key"
```

### SnapLogic ETL Snap

Configure via snap properties in the SnapLogic UI:
- Source API URL
- Target API URL
- Authentication settings
- Batch size
- Validation/normalization flags

## Performance Considerations

Both implementations optimize performance through:

1. **Batch Processing**: Configurable batch size (default: 100 records)
2. **Connection Pooling**: HTTP client connection pooling
3. **Stream Processing**: Efficient data transformation
4. **Memory Management**: Batch-based processing for large datasets

### Recommended Batch Sizes

| Dataset Size | Recommended Batch Size |
|--------------|------------------------|
| < 1,000 | 100 |
| 1,000 - 10,000 | 500 |
| 10,000 - 100,000 | 1,000 |
| > 100,000 | 2,000 |

## Error Handling

Both implementations provide comprehensive error handling:

### Configuration Errors
- Missing required configuration
- Invalid configuration values
- Throws exceptions with descriptive messages

### Runtime Errors
- **API Connection Failures**: Falls back to mock data
- **Authentication Failures**: Logs error and continues
- **Validation Failures**: Skips invalid records
- **Batch Load Failures**: Logs error and continues with next batch

## Logging

Both implementations provide detailed logging:

- **INFO**: Process flow, record counts, batch progress
- **WARN**: API failures, validation issues, fallbacks
- **DEBUG**: Individual record processing, HTTP details
- **ERROR**: Fatal errors, exceptions

## Mock Data

Both implementations include mock data generation for demonstration and testing purposes. When the source API is unavailable, the ETL jobs automatically fall back to mock data containing 3-5 sample customer records.

## Use Cases

### IBM Java SDK Core ETL
Best suited for:
- Standalone batch processing
- Scheduled jobs (cron, Jenkins, etc.)
- Custom integration requirements
- IBM Cloud service integration
- Microservices architecture

### SnapLogic ETL Snap
Best suited for:
- SnapLogic platform users
- Visual pipeline development
- Enterprise integration scenarios
- Rapid development and deployment
- Built-in monitoring and scheduling

## Testing

### IBM Java SDK Core ETL
```bash
cd ibm-java-sdk-etl
mvn test
```

### SnapLogic ETL Snap
```bash
cd snaplogic-etl
mvn test
```

Or test within SnapLogic platform using test pipelines.

## Building

### IBM Java SDK Core ETL
```bash
cd ibm-java-sdk-etl
mvn clean install
```

Produces: `target/ibm-java-sdk-etl-1.0.0.jar`

### SnapLogic ETL Snap
```bash
cd snaplogic-etl
mvn clean install -DskipTests -DVERSION=1 -Dsl_build=0001
```

Produces: `target/customer-etl-snap-1.0.0.jar`

## Dependencies

### IBM Java SDK Core ETL
- IBM Java SDK Core 9.24.3
- Gson 2.10.1
- SLF4J 2.0.9
- OkHttp (transitive)

### SnapLogic ETL Snap
- SnapLogic SDK 4.9.0
- Gson 2.8.9
- Apache HttpClient 4.5.13
- SLF4J 1.7.36

## Migration Guide

### From IBM Java SDK Core to SnapLogic

1. **Build the SnapLogic snap** using Maven
2. **Upload the JAR** to SnapLogic Manager
3. **Create a pipeline** with the Customer ETL snap
4. **Configure properties** (map environment variables to snap properties)
5. **Test the pipeline** with sample data
6. **Schedule the pipeline** using SnapLogic Scheduler

### From SnapLogic to IBM Java SDK Core

1. **Extract configuration** from snap properties
2. **Set environment variables** with the same values
3. **Build the JAR** using Maven
4. **Deploy the JAR** to your execution environment
5. **Schedule execution** using your preferred scheduler

## Best Practices

1. **Use API Keys**: Prefer API key authentication over basic auth
2. **Configure Batch Size**: Adjust based on dataset size and network
3. **Enable Validation**: Always validate data in production
4. **Monitor Logs**: Regularly check logs for warnings and errors
5. **Test with Mock Data**: Use mock data for development
6. **Handle Errors Gracefully**: Implement proper error handling
7. **Document Pipelines**: Add descriptions and comments
8. **Version Control**: Track versions and changes

## Troubleshooting

### Issue: Authentication Failures
**Solution**: Verify API keys/credentials and permissions

### Issue: Connection Timeouts
**Solution**: Check network connectivity and API availability

### Issue: Out of Memory Errors
**Solution**: Reduce batch size or increase heap size

### Issue: All Records Filtered Out
**Solution**: Check validation rules and source data quality

### Issue: Slow Performance
**Solution**: Increase batch size or optimize network

## Resources

### IBM Java SDK Core
- [GitHub Repository](https://github.com/IBM/java-sdk-core)
- [Javadoc](https://ibm.github.io/java-sdk-core/)
- [Authentication Guide](https://github.com/IBM/java-sdk-core/blob/main/Authentication.md)

### SnapLogic
- [Developer Portal](http://developer.snaplogic.com)
- [SDK Documentation](https://docs-snaplogic.atlassian.net/wiki/spaces/SD/overview)
- [Custom Snap Development](https://docs-snaplogic.atlassian.net/wiki/spaces/SD/pages/1438414/Developing+Snaps)

## License

These examples are provided for educational purposes.

## Contributing

To extend these examples:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## Support

For questions or issues:
- IBM Java SDK Core: https://github.com/IBM/java-sdk-core/issues
- SnapLogic: http://developer.snaplogic.com
