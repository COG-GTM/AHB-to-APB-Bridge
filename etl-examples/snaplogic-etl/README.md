# SnapLogic Customer ETL Snap

A custom SnapLogic snap for performing ETL (Extract, Transform, Load) operations on customer data. This snap provides a complete ETL pipeline within the SnapLogic platform.

## Overview

This custom snap demonstrates how to build a production-ready ETL component for SnapLogic. It extracts customer data from a source API, transforms and validates the data, and loads it into a target system - all within a single snap component.

## Architecture

The Customer ETL Snap is built using the SnapLogic SDK and follows SnapLogic's snap development best practices:

```
CustomerETLSnap (Main Snap Component)
    ├── Extract Phase (HTTP GET from source API)
    ├── Transform Phase (Validation + Normalization + Enrichment)
    └── Load Phase (HTTP POST to target API in batches)
```

## Features

### Extract Phase
- HTTP-based data extraction from REST APIs
- Support for multiple authentication methods:
  - None (public APIs)
  - Basic Authentication
  - API Key (Bearer token)
- Automatic fallback to mock data for demonstration
- JSON response parsing

### Transform Phase
- **Data Validation**:
  - Required field validation (customer ID, email, names)
  - Email format validation
  - Configurable validation rules
  
- **Data Normalization**:
  - Name capitalization standardization
  - Email address normalization (lowercase)
  - Phone number formatting
  - State/country code standardization
  - Status normalization
  
- **Data Enrichment**:
  - Default value assignment for missing fields
  - Data quality improvements

### Load Phase
- Batch processing for efficient data loading
- Configurable batch size
- HTTP-based data loading to REST APIs
- Support for multiple authentication methods
- Comprehensive error handling

## Snap Properties

The snap exposes the following configurable properties:

| Property | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| Source API URL | String | Yes | - | URL of the source API endpoint |
| Target API URL | String | Yes | - | URL of the target API endpoint |
| Source Authentication Type | Dropdown | No | None | Authentication method for source (None, Basic, API Key) |
| Source Username | String | No | - | Username for basic authentication (source) |
| Source Password | String | No | - | Password for basic authentication (source) |
| Source API Key | String | No | - | API key for bearer token authentication (source) |
| Target Authentication Type | Dropdown | No | None | Authentication method for target (None, Basic, API Key) |
| Target Username | String | No | - | Username for basic authentication (target) |
| Target Password | String | No | - | Password for basic authentication (target) |
| Target API Key | String | No | - | API key for bearer token authentication (target) |
| Batch Size | Integer | No | 100 | Number of records to process per batch |
| Validate Data | Boolean | No | true | Enable/disable data validation |
| Normalize Data | Boolean | No | true | Enable/disable data normalization |

## Snap Capabilities

### Inputs
- **Minimum**: 0
- **Maximum**: 1
- **Accepts**: Document view type
- The snap can run without input (trigger-based) or accept input documents

### Outputs
- **Minimum**: 1
- **Maximum**: 1
- **Offers**: Document view type
- Outputs a summary document with ETL execution results

### Category
- **Transform**: This snap is categorized as a Transform snap in SnapLogic

## Building the Snap

### Prerequisites
- Java 8 or higher
- Maven 3.6 or higher
- Access to SnapLogic Maven repository

### Build Commands

```bash
cd etl-examples/snaplogic-etl

# First build
mvn clean install -DskipTests -DVERSION=1 -Dsl_build=0001

# Subsequent builds (increment sl_build number)
mvn clean install -DskipTests -DVERSION=1 -Dsl_build=0002
mvn clean install -DskipTests -DVERSION=1 -Dsl_build=0003
```

The build produces a JAR file in the `target/` directory that can be uploaded to SnapLogic.

## Installing the Snap

1. Build the snap using Maven (see above)
2. Log in to SnapLogic Manager
3. Navigate to **Manager** > **Snaplex** > **Snap Packs**
4. Click **Upload Snap Pack**
5. Select the generated JAR file from `target/customer-etl-snap-1.0.0.jar`
6. The snap will be available in the snap palette under the Transform category

## Using the Snap in a Pipeline

### Basic Pipeline Example

```
[Trigger] → [Customer ETL Snap] → [Mapper] → [Output]
```

### Configuration Example

1. **Drag and drop** the Customer ETL snap onto the canvas
2. **Configure properties**:
   - Source API URL: `https://api.example.com/customers`
   - Target API URL: `https://warehouse.example.com/customers`
   - Source Authentication Type: `API Key`
   - Source API Key: `your-source-api-key`
   - Target Authentication Type: `Basic`
   - Target Username: `admin`
   - Target Password: `password123`
   - Batch Size: `100`
   - Validate Data: `true`
   - Normalize Data: `true`

3. **Connect** the snap to upstream and downstream snaps
4. **Validate** the pipeline
5. **Execute** the pipeline

## Output Document Format

The snap outputs a document with the following structure:

```json
{
  "success": true,
  "message": "ETL process completed successfully",
  "recordsExtracted": 150,
  "recordsTransformed": 145,
  "recordsLoaded": 145,
  "startTime": "2025-11-19T16:00:00",
  "endTime": "2025-11-19T16:00:15"
}
```

### Output Fields

| Field | Type | Description |
|-------|------|-------------|
| success | Boolean | Whether the ETL process completed successfully |
| message | String | Success or error message |
| recordsExtracted | Integer | Number of records extracted from source |
| recordsTransformed | Integer | Number of records that passed transformation |
| recordsLoaded | Integer | Number of records successfully loaded to target |
| startTime | String | ISO 8601 timestamp of ETL start |
| endTime | String | ISO 8601 timestamp of ETL completion |

## Data Flow

### 1. Extract Phase
```
Source API → HTTP GET Request → JSON Response → Parse → CustomerRecord List
```

The snap:
1. Constructs HTTP GET request to source API
2. Adds authentication headers based on configuration
3. Executes request and receives JSON response
4. Parses JSON into CustomerRecord objects
5. Falls back to mock data if API is unavailable

### 2. Transform Phase
```
Raw Records → Validation → Normalization → Enrichment → Clean Records
```

For each record:
1. **Validate**: Check required fields and data formats
2. **Normalize**: Standardize data formats (names, emails, phones, etc.)
3. **Enrich**: Add default values for missing optional fields
4. **Filter**: Remove invalid records from the pipeline

### 3. Load Phase
```
Clean Records → Batch Creation → HTTP POST Request → Target API → Success/Failure
```

The snap:
1. Splits records into batches (configurable size)
2. Creates JSON payload for each batch
3. Adds authentication headers based on configuration
4. Makes HTTP POST request to target API
5. Tracks success/failure for each batch

## Data Validation Rules

The snap enforces the following validation rules when `Validate Data` is enabled:

| Rule | Action |
|------|--------|
| Missing customer ID | Skip record |
| Invalid email format | Skip record |
| Missing first name | Skip record |
| Missing last name | Skip record |
| Missing phone | Continue (optional field) |
| Missing address | Continue (optional field) |

## Data Normalization Rules

The snap applies the following normalization when `Normalize Data` is enabled:

| Field | Normalization |
|-------|---------------|
| First Name | Capitalize first letter, lowercase rest |
| Last Name | Capitalize first letter, lowercase rest |
| Email | Convert to lowercase, trim whitespace |
| Phone | Format as XXX-XXX-XXXX |
| State | Convert to uppercase |
| Country | Convert to uppercase |
| Status | Convert to lowercase |

## Data Enrichment Rules

The snap applies the following enrichment rules:

| Field | Default Value |
|-------|---------------|
| Status | "active" |
| Country | "USA" |
| Total Purchases | 0.0 |

## Error Handling

The snap implements comprehensive error handling:

### Configuration Errors
- Missing required properties (Source URL, Target URL)
- Invalid batch size (must be > 0)
- Throws `ConfigurationException` with descriptive message

### Runtime Errors
- **API Connection Failures**: Falls back to mock data, logs warning
- **Authentication Failures**: Logs error, continues with available data
- **Validation Failures**: Skips invalid records, logs debug message
- **Batch Load Failures**: Logs error, continues with next batch
- **Fatal Errors**: Throws `ExecutionException` with error details

## Logging

The snap provides comprehensive logging at multiple levels:

### INFO Level
- ETL process start/completion
- Record counts at each phase
- Batch processing progress
- API connection status

### WARN Level
- API connection failures
- Invalid authentication
- Batch load failures
- Fallback to mock data

### DEBUG Level
- Individual record validation results
- Detailed transformation steps
- HTTP request/response details

### Example Log Output

```
[INFO] Starting Customer ETL process
[INFO] Extracting data from: https://api.example.com/customers
[INFO] Extracted 150 records
[INFO] Transforming 150 records
[DEBUG] Skipping invalid record: CUST999
[INFO] Transformed 145 records
[INFO] Loading 145 records to: https://warehouse.example.com/customers
[INFO] Loaded batch 1/2
[INFO] Loaded batch 2/2
[INFO] Loaded 145 records
```

## Performance Considerations

1. **Batch Processing**: Configurable batch size optimizes network calls
2. **HTTP Connection Pooling**: Apache HttpClient provides connection pooling
3. **Memory Efficiency**: Processes records in batches to manage memory
4. **Configurable Validation**: Can disable validation for performance

### Recommended Settings

| Dataset Size | Batch Size | Validate | Normalize |
|--------------|------------|----------|-----------|
| < 1,000 records | 100 | true | true |
| 1,000 - 10,000 | 500 | true | true |
| 10,000 - 100,000 | 1,000 | true | false |
| > 100,000 | 2,000 | false | false |

## Comparison with IBM Java SDK Core Implementation

This SnapLogic snap provides the same ETL functionality as the IBM Java SDK Core implementation, but with key differences:

### Similarities
- Same ETL logic (Extract, Transform, Load)
- Same validation rules
- Same normalization rules
- Same data enrichment
- Same batch processing approach

### Differences

| Aspect | IBM Java SDK Core | SnapLogic Snap |
|--------|-------------------|----------------|
| **Deployment** | Standalone Java application | SnapLogic platform component |
| **Configuration** | Environment variables | Snap properties UI |
| **Integration** | Requires custom integration code | Native SnapLogic integration |
| **Monitoring** | Custom logging | SnapLogic Dashboard |
| **Scheduling** | External scheduler required | SnapLogic Scheduler |
| **Error Handling** | Custom implementation | SnapLogic error handling |
| **Authentication** | IBM SDK authenticators | HTTP headers |
| **Scalability** | Manual scaling | SnapLogic Snaplex scaling |

## Extending the Snap

### Adding New Properties

Add to `defineProperties()` method:

```java
propertyBuilder.describe("newProperty", "New Property Description")
    .required()
    .defaultValue("default")
    .add();
```

### Adding New Validation Rules

Add to `isValidRecord()` method:

```java
if (record.getNewField() == null || !isValidNewField(record.getNewField())) {
    return false;
}
```

### Adding New Transformations

Add to `normalizeRecord()` method:

```java
if (record.getNewField() != null) {
    record.setNewField(transformNewField(record.getNewField()));
}
```

### Supporting New Data Sources

Modify `extractData()` method to support additional protocols:

```java
if (sourceType.equals("database")) {
    return extractFromDatabase();
} else if (sourceType.equals("file")) {
    return extractFromFile();
}
```

## Testing the Snap

### Unit Testing

Create test class in `src/test/java`:

```java
public class CustomerETLSnapTest {
    @Test
    public void testValidation() {
        // Test validation logic
    }
    
    @Test
    public void testNormalization() {
        // Test normalization logic
    }
}
```

### Integration Testing

1. Deploy snap to SnapLogic
2. Create test pipeline
3. Use mock data or test APIs
4. Verify output documents
5. Check logs for errors

## Troubleshooting

### Issue: Snap Not Appearing in Palette
**Solution**: Verify JAR was uploaded correctly and Snaplex was restarted

### Issue: Authentication Failures
**Solution**: Verify credentials and authentication type configuration

### Issue: No Records Extracted
**Solution**: Check source API URL and network connectivity

### Issue: All Records Filtered Out
**Solution**: Check validation rules and source data quality

### Issue: Batch Load Failures
**Solution**: Verify target API endpoint and authentication

## Best Practices

1. **Use API Keys**: Prefer API key authentication over basic auth
2. **Configure Batch Size**: Adjust based on dataset size and network
3. **Enable Validation**: Always validate data in production
4. **Monitor Logs**: Regularly check logs for warnings and errors
5. **Test with Mock Data**: Use mock data for development and testing
6. **Handle Errors Gracefully**: Implement proper error handling in pipelines
7. **Document Pipelines**: Add descriptions to snaps and pipelines
8. **Version Control**: Track snap versions and changes

## Dependencies

The snap uses the following key dependencies:

- **SnapLogic SDK 4.9.0**: Core snap development framework
- **Gson 2.8.9**: JSON parsing and serialization
- **Apache HttpClient 4.5.13**: HTTP communication
- **SLF4J 1.7.36**: Logging framework

## Resources

- [SnapLogic Developer Portal](http://developer.snaplogic.com)
- [SnapLogic SDK Documentation](https://docs-snaplogic.atlassian.net/wiki/spaces/SD/overview)
- [Custom Snap Development Guide](https://docs-snaplogic.atlassian.net/wiki/spaces/SD/pages/1438414/Developing+Snaps)
- [Snap API Reference](https://docs-snaplogic.atlassian.net/wiki/spaces/SD/pages/1438416/Snap+API)

## License

This example is provided for educational purposes.

## Support

For issues with SnapLogic SDK, visit: http://developer.snaplogic.com
