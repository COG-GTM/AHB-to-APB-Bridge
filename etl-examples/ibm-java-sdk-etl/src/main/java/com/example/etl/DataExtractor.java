package com.example.etl;

import com.google.gson.Gson;
import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.ibm.cloud.sdk.core.http.HttpMediaType;
import com.ibm.cloud.sdk.core.http.RequestBuilder;
import com.ibm.cloud.sdk.core.http.Response;
import com.ibm.cloud.sdk.core.http.ServiceCall;
import com.ibm.cloud.sdk.core.security.Authenticator;
import com.ibm.cloud.sdk.core.service.BaseService;
import okhttp3.OkHttpClient;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

public class DataExtractor extends BaseService {
    private static final Logger logger = LoggerFactory.getLogger(DataExtractor.class);
    private static final Gson gson = new Gson();
    private final String serviceUrl;
    
    public DataExtractor(String serviceUrl, Authenticator authenticator) {
        super("DataExtractor", authenticator);
        this.serviceUrl = serviceUrl;
        this.setServiceUrl(serviceUrl);
    }
    
    public List<CustomerRecord> extract() {
        logger.info("Extracting customer data from: {}", serviceUrl);
        List<CustomerRecord> records = new ArrayList<>();
        
        try {
            RequestBuilder builder = RequestBuilder.get(RequestBuilder.resolveRequestUrl(serviceUrl, "/api/customers", null));
            builder.header("Accept", HttpMediaType.APPLICATION_JSON);
            
            ServiceCall<String> call = createServiceCall(builder.build(), String.class);
            Response<String> response = call.execute();
            
            if (response.getStatusCode() == 200) {
                String responseBody = response.getResult();
                records = parseCustomerData(responseBody);
                logger.info("Successfully extracted {} customer records", records.size());
            } else {
                logger.warn("Received non-200 status code: {}. Using mock data for demonstration.", response.getStatusCode());
                records = generateMockData();
            }
            
        } catch (Exception e) {
            logger.warn("Failed to extract data from source API: {}. Using mock data for demonstration.", e.getMessage());
            records = generateMockData();
        }
        
        return records;
    }
    
    private List<CustomerRecord> parseCustomerData(String jsonResponse) {
        List<CustomerRecord> records = new ArrayList<>();
        
        try {
            JsonObject responseObj = gson.fromJson(jsonResponse, JsonObject.class);
            JsonArray customers = responseObj.getAsJsonArray("customers");
            
            for (JsonElement element : customers) {
                JsonObject customerObj = element.getAsJsonObject();
                CustomerRecord record = new CustomerRecord();
                
                record.setCustomerId(getStringValue(customerObj, "customer_id"));
                record.setFirstName(getStringValue(customerObj, "first_name"));
                record.setLastName(getStringValue(customerObj, "last_name"));
                record.setEmail(getStringValue(customerObj, "email"));
                record.setPhone(getStringValue(customerObj, "phone"));
                record.setAddress(getStringValue(customerObj, "address"));
                record.setCity(getStringValue(customerObj, "city"));
                record.setState(getStringValue(customerObj, "state"));
                record.setZipCode(getStringValue(customerObj, "zip_code"));
                record.setCountry(getStringValue(customerObj, "country"));
                record.setStatus(getStringValue(customerObj, "status"));
                
                if (customerObj.has("total_purchases")) {
                    record.setTotalPurchases(customerObj.get("total_purchases").getAsDouble());
                }
                
                if (customerObj.has("registration_date")) {
                    record.setRegistrationDate(LocalDate.parse(customerObj.get("registration_date").getAsString()));
                }
                
                records.add(record);
            }
            
        } catch (Exception e) {
            logger.error("Error parsing customer data", e);
        }
        
        return records;
    }
    
    private String getStringValue(JsonObject obj, String key) {
        if (obj.has(key) && !obj.get(key).isJsonNull()) {
            return obj.get(key).getAsString();
        }
        return null;
    }
    
    private List<CustomerRecord> generateMockData() {
        logger.info("Generating mock customer data for demonstration");
        List<CustomerRecord> records = new ArrayList<>();
        
        CustomerRecord record1 = new CustomerRecord();
        record1.setCustomerId("CUST001");
        record1.setFirstName("John");
        record1.setLastName("Doe");
        record1.setEmail("john.doe@example.com");
        record1.setPhone("555-0101");
        record1.setAddress("123 Main St");
        record1.setCity("New York");
        record1.setState("NY");
        record1.setZipCode("10001");
        record1.setCountry("USA");
        record1.setStatus("active");
        record1.setTotalPurchases(1250.50);
        record1.setRegistrationDate(LocalDate.of(2023, 1, 15));
        records.add(record1);
        
        CustomerRecord record2 = new CustomerRecord();
        record2.setCustomerId("CUST002");
        record2.setFirstName("Jane");
        record2.setLastName("Smith");
        record2.setEmail("jane.smith@example.com");
        record2.setPhone("555-0102");
        record2.setAddress("456 Oak Ave");
        record2.setCity("Los Angeles");
        record2.setState("CA");
        record2.setZipCode("90001");
        record2.setCountry("USA");
        record2.setStatus("active");
        record2.setTotalPurchases(2340.75);
        record2.setRegistrationDate(LocalDate.of(2023, 2, 20));
        records.add(record2);
        
        CustomerRecord record3 = new CustomerRecord();
        record3.setCustomerId("CUST003");
        record3.setFirstName("Bob");
        record3.setLastName("Johnson");
        record3.setEmail("bob.johnson@example.com");
        record3.setPhone("555-0103");
        record3.setAddress("789 Pine Rd");
        record3.setCity("Chicago");
        record3.setState("IL");
        record3.setZipCode("60601");
        record3.setCountry("USA");
        record3.setStatus("inactive");
        record3.setTotalPurchases(450.25);
        record3.setRegistrationDate(LocalDate.of(2022, 11, 10));
        records.add(record3);
        
        CustomerRecord record4 = new CustomerRecord();
        record4.setCustomerId("CUST004");
        record4.setFirstName("Alice");
        record4.setLastName("Williams");
        record4.setEmail("alice.williams@example.com");
        record4.setPhone("555-0104");
        record4.setAddress("321 Elm St");
        record4.setCity("Houston");
        record4.setState("TX");
        record4.setZipCode("77001");
        record4.setCountry("USA");
        record4.setStatus("active");
        record4.setTotalPurchases(3150.00);
        record4.setRegistrationDate(LocalDate.of(2023, 3, 5));
        records.add(record4);
        
        CustomerRecord record5 = new CustomerRecord();
        record5.setCustomerId("CUST005");
        record5.setFirstName("Charlie");
        record5.setLastName("Brown");
        record5.setEmail("charlie.brown@example.com");
        record5.setPhone("555-0105");
        record5.setAddress("654 Maple Dr");
        record5.setCity("Phoenix");
        record5.setState("AZ");
        record5.setZipCode("85001");
        record5.setCountry("USA");
        record5.setStatus("active");
        record5.setTotalPurchases(890.50);
        record5.setRegistrationDate(LocalDate.of(2023, 4, 12));
        records.add(record5);
        
        return records;
    }
}
