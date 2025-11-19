# IBM Java SDK Core ETL Job

A comprehensive ETL (Extract, Transform, Load) job implementation using the IBM Java SDK Core library for authentication and HTTP communication.

## Overview

This ETL job demonstrates how to build a production-ready data pipeline using IBM Java SDK Core. The implementation extracts customer data from a source API, transforms and validates the data, and loads it into a target system.

## Architecture

The ETL job follows a modular architecture with clear separation of concerns:

```
CustomerDataETL (Main Orchestrator)
    ├── DataExtractor (Extract Phase)
    ├── DataTransformer (Transform Phase)
    └── DataLoader (Load Phase)
```

### Components

#### 1. CustomerDataETL
The main orchestrator class that coordinates the entire ETL pipeline. It manages the execution flow and handles error reporting.

**Key Features:**
- Orchestrates the three ETL phases
- Provides comprehensive logging and monitoring
- Tracks metrics (records extracted, transformed, loaded)
- Handles errors gracefully with detailed reporting

#### 2. DataExtractor
Extracts customer data from a source API using IBM Java SDK Core's HTTP client capabilities.

**Key Features:**
- Uses IBM Java SDK Core's `BaseService` for HTTP communication
- Supports multiple authentication methods (IAM, Basic Auth)
- Implements fallback to mock data for demonstration purposes
- Parses JSON responses into CustomerRecord objects
- Comprehensive error handling and logging

#### 3. DataTransformer
Transforms and validates extracted data to ensure data quality.

**Key Features:**
- **Validation**: Filters out invalid records (missing IDs, invalid emails, missing names)
- **Normalization**: 
  - Standardizes name capitalization
  - Normalizes email addresses (lowercase)
  - Formats phone numbers (555-0101 format)
  - Standardizes zip codes
  - Normalizes state and country codes
- **Enrichment**: Adds default values for missing fields
- Stream-based processing for efficiency

#### 4. DataLoader
Loads transformed data to a target API in batches.

**Key Features:**
- Batch processing (configurable batch size, default 100 records)
- Uses IBM Java SDK Core for authenticated HTTP requests
- Creates properly formatted JSON payloads
- Implements retry logic and error handling
- Simulates successful loads for demonstration purposes

#### 5. CustomerRecord
POJO (Plain Old Java Object) representing a customer record with all relevant fields.

## IBM Java SDK Core Integration

This ETL job leverages several key features of the IBM Java SDK Core:

### 1. Authentication
The SDK supports multiple authentication methods:

```java
// IAM Authentication (recommended for IBM Cloud services)
Authenticator iamAuth = new IamAuthenticator("your-api-key");

// Basic Authentication (for testing/development)
Authenticator basicAuth = new BasicAuthenticator("username", "password");
```

### 2. HTTP Communication
The `BaseService` class provides:
- Built-in HTTP client (OkHttp)
- Request/response handling
- Automatic authentication header injection
- Comprehensive logging capabilities

```java
public class DataExtractor extends BaseService {
    public DataExtractor(String serviceUrl, Authenticator authenticator) {
        super("DataExtractor", authenticator);
        this.setServiceUrl(serviceUrl);
    }
    
    public List<CustomerRecord> extract() {
        RequestBuilder builder = RequestBuilder.get(
            RequestBuilder.resolveRequestUrl(serviceUrl, "/api/customers", null)
        );
        builder.header("Accept", HttpMediaType.APPLICATION_JSON);
        
        ServiceCall<String> call = createServiceCall(builder.build(), String.class);
        Response<String> response = call.execute();
        // Process response...
    }
}
```

### 3. Service Calls
The SDK provides a clean abstraction for making service calls:
- Type-safe response handling
- Automatic error handling
- Support for synchronous and asynchronous calls

## Prerequisites

- Java 11 or higher
- Maven 3.6 or higher
- IBM Java SDK Core 9.24.3

## Building the Project

```bash
cd etl-examples/ibm-java-sdk-etl
mvn clean install
```

This will:
1. Download all dependencies
2. Compile the Java source files
3. Run tests (if any)
4. Package the application into a JAR file

## Configuration

The ETL job can be configured using environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `SOURCE_API_URL` | Source API endpoint | `https://api.example.com/customers` |
| `TARGET_API_URL` | Target API endpoint | `https://api.target.com/customers` |
| `SOURCE_API_KEY` | API key for source authentication | Uses basic auth if not set |
| `TARGET_API_KEY` | API key for target authentication | Uses basic auth if not set |

### Example Configuration

```bash
export SOURCE_API_URL="https://api.mycompany.com/customers"
export TARGET_API_URL="https://warehouse.mycompany.com/customers"
export SOURCE_API_KEY="your-source-api-key"
export TARGET_API_KEY="your-target-api-key"
```

## Running the ETL Job

### Using Maven

```bash
mvn exec:java -Dexec.mainClass="com.example.etl.CustomerDataETL"
```

### Using the JAR file

```bash
java -jar target/ibm-java-sdk-etl-1.0.0.jar
```

### With Environment Variables

```bash
SOURCE_API_URL="https://api.example.com" \
TARGET_API_URL="https://target.example.com" \
SOURCE_API_KEY="key123" \
TARGET_API_KEY="key456" \
java -jar target/ibm-java-sdk-etl-1.0.0.jar
```

## ETL Process Flow

### 1. Extract Phase
```
Source API → HTTP GET Request → JSON Response → Parse → CustomerRecord List
```

The extractor:
1. Authenticates using IBM Java SDK Core authenticators
2. Makes HTTP GET request to source API
3. Parses JSON response into CustomerRecord objects
4. Falls back to mock data if API is unavailable (for demonstration)

### 2. Transform Phase
```
Raw Records → Validation → Normalization → Enrichment → Clean Records
```

The transformer:
1. **Validates** each record:
   - Checks for required fields (ID, email, names)
   - Validates email format
   - Filters out invalid records

2. **Normalizes** data:
   - Standardizes name capitalization
   - Converts emails to lowercase
   - Formats phone numbers consistently
   - Normalizes zip codes and state codes

3. **Enriches** data:
   - Adds default values for missing fields
   - Sets default status to "active"
   - Sets default country to "USA"

### 3. Load Phase
```
Clean Records → Batch Creation → HTTP POST Request → Target API → Success/Failure
```

The loader:
1. Splits records into batches (default: 100 records per batch)
2. Creates JSON payload for each batch
3. Authenticates using IBM Java SDK Core
4. Makes HTTP POST request to target API
5. Tracks success/failure for each batch

## Output and Logging

The ETL job provides comprehensive logging at multiple levels:

### INFO Level
- ETL job start/completion times
- Phase transitions (Extract → Transform → Load)
- Record counts at each phase
- Batch processing progress

### WARN Level
- Invalid records being filtered out
- API connection issues
- Fallback to mock data

### DEBUG Level
- Individual record processing details
- HTTP request/response details
- Detailed transformation steps

### Example Output

```
[INFO] Initializing Customer Data ETL Job
[INFO] Starting ETL job execution at 2025-11-19T16:00:00
[INFO] Phase 1: Extracting data from source
[INFO] Extracted 5 records
[INFO] Phase 2: Transforming data
[INFO] Transformation complete. 5 records passed validation and transformation
[INFO] Phase 3: Loading data to target
[INFO] Loading batch 1/1 (5 records)
[INFO] Successfully loaded 5 records in this batch
[INFO] Total records loaded: 5/5
[INFO] ETL job completed at 2025-11-19T16:00:01
[INFO] ETL Result: {"success":true,"message":"ETL job completed successfully","recordsExtracted":5,"recordsTransformed":5,"recordsLoaded":5}
```

## Error Handling

The ETL job implements comprehensive error handling:

1. **API Connection Errors**: Falls back to mock data for demonstration
2. **Validation Errors**: Logs and skips invalid records
3. **Batch Load Errors**: Logs error and continues with next batch
4. **Fatal Errors**: Logs error and returns failure status

## Data Quality Rules

The transformer enforces the following data quality rules:

| Rule | Action |
|------|--------|
| Missing customer ID | Skip record |
| Invalid email format | Skip record |
| Missing first/last name | Skip record |
| Missing phone | Continue (optional field) |
| Missing address fields | Continue (optional fields) |
| Missing status | Set default "active" |
| Missing country | Set default "USA" |
| Missing total purchases | Set default 0.0 |

## Performance Considerations

1. **Batch Processing**: Records are loaded in batches to optimize network calls
2. **Stream Processing**: Transformation uses Java Streams for efficiency
3. **Connection Pooling**: IBM Java SDK Core uses OkHttp with connection pooling
4. **Configurable Batch Size**: Adjust `BATCH_SIZE` constant in DataLoader for your needs

## Extending the ETL Job

### Adding New Data Sources

Extend `DataExtractor` or create a new extractor class:

```java
public class DatabaseExtractor extends BaseService {
    // Implement extraction from database
}
```

### Adding New Transformations

Add methods to `DataTransformer`:

```java
private CustomerRecord customTransformation(CustomerRecord record) {
    // Your custom transformation logic
    return record;
}
```

### Adding New Destinations

Extend `DataLoader` or create a new loader class:

```java
public class DatabaseLoader extends BaseService {
    // Implement loading to database
}
```

## Dependencies

The project uses the following key dependencies:

- **IBM Java SDK Core 9.24.3**: Authentication and HTTP communication
- **Gson 2.10.1**: JSON parsing and serialization
- **SLF4J 2.0.9**: Logging framework
- **OkHttp** (transitive via IBM SDK): HTTP client

## Best Practices Demonstrated

1. **Separation of Concerns**: Each component has a single responsibility
2. **Dependency Injection**: Components receive dependencies via constructor
3. **Comprehensive Logging**: Detailed logging at appropriate levels
4. **Error Handling**: Graceful error handling with fallbacks
5. **Configuration**: Externalized configuration via environment variables
6. **Data Validation**: Strict validation rules for data quality
7. **Batch Processing**: Efficient batch processing for large datasets
8. **Type Safety**: Strong typing with POJOs

## Troubleshooting

### Issue: Authentication Failures
**Solution**: Verify your API keys are correct and have proper permissions

### Issue: Connection Timeouts
**Solution**: Check network connectivity and API endpoint availability

### Issue: Out of Memory Errors
**Solution**: Reduce batch size or implement pagination for large datasets

### Issue: Invalid Records Being Skipped
**Solution**: Check logs for validation errors and fix source data

## License

This example is provided for educational purposes.

## Support

For issues with IBM Java SDK Core, visit: https://github.com/IBM/java-sdk-core
