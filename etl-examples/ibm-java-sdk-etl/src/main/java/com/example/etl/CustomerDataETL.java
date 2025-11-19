package com.example.etl;

import com.google.gson.Gson;
import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import com.ibm.cloud.sdk.core.http.HttpMediaType;
import com.ibm.cloud.sdk.core.http.RequestBuilder;
import com.ibm.cloud.sdk.core.http.Response;
import com.ibm.cloud.sdk.core.http.ServiceCall;
import com.ibm.cloud.sdk.core.security.Authenticator;
import com.ibm.cloud.sdk.core.security.BasicAuthenticator;
import com.ibm.cloud.sdk.core.security.IamAuthenticator;
import com.ibm.cloud.sdk.core.service.BaseService;
import okhttp3.OkHttpClient;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;

public class CustomerDataETL {
    private static final Logger logger = LoggerFactory.getLogger(CustomerDataETL.class);
    private static final Gson gson = new Gson();
    
    private final DataExtractor extractor;
    private final DataTransformer transformer;
    private final DataLoader loader;
    
    public CustomerDataETL(String sourceUrl, String targetUrl, Authenticator sourceAuth, Authenticator targetAuth) {
        this.extractor = new DataExtractor(sourceUrl, sourceAuth);
        this.transformer = new DataTransformer();
        this.loader = new DataLoader(targetUrl, targetAuth);
    }
    
    public ETLResult execute() {
        logger.info("Starting ETL job execution at {}", LocalDateTime.now());
        ETLResult result = new ETLResult();
        
        try {
            logger.info("Phase 1: Extracting data from source");
            List<CustomerRecord> rawData = extractor.extract();
            result.recordsExtracted = rawData.size();
            logger.info("Extracted {} records", rawData.size());
            
            logger.info("Phase 2: Transforming data");
            List<CustomerRecord> transformedData = transformer.transform(rawData);
            result.recordsTransformed = transformedData.size();
            logger.info("Transformed {} records", transformedData.size());
            
            logger.info("Phase 3: Loading data to target");
            int loadedCount = loader.load(transformedData);
            result.recordsLoaded = loadedCount;
            logger.info("Loaded {} records", loadedCount);
            
            result.success = true;
            result.message = "ETL job completed successfully";
            
        } catch (Exception e) {
            logger.error("ETL job failed", e);
            result.success = false;
            result.message = "ETL job failed: " + e.getMessage();
        }
        
        result.completedAt = LocalDateTime.now();
        logger.info("ETL job completed at {}", result.completedAt);
        
        return result;
    }
    
    public static void main(String[] args) {
        logger.info("Initializing Customer Data ETL Job");
        
        String sourceUrl = System.getenv("SOURCE_API_URL");
        String targetUrl = System.getenv("TARGET_API_URL");
        String sourceApiKey = System.getenv("SOURCE_API_KEY");
        String targetApiKey = System.getenv("TARGET_API_KEY");
        
        if (sourceUrl == null || targetUrl == null) {
            sourceUrl = "https://api.example.com/customers";
            targetUrl = "https://api.target.com/customers";
            logger.warn("Using default URLs for demonstration purposes");
        }
        
        Authenticator sourceAuth;
        Authenticator targetAuth;
        
        if (sourceApiKey != null && !sourceApiKey.isEmpty()) {
            sourceAuth = new IamAuthenticator(sourceApiKey);
        } else {
            sourceAuth = new BasicAuthenticator("demo_user", "demo_password");
            logger.warn("Using basic authentication for demonstration purposes");
        }
        
        if (targetApiKey != null && !targetApiKey.isEmpty()) {
            targetAuth = new IamAuthenticator(targetApiKey);
        } else {
            targetAuth = new BasicAuthenticator("demo_user", "demo_password");
            logger.warn("Using basic authentication for demonstration purposes");
        }
        
        CustomerDataETL etl = new CustomerDataETL(sourceUrl, targetUrl, sourceAuth, targetAuth);
        ETLResult result = etl.execute();
        
        logger.info("ETL Result: {}", gson.toJson(result));
        
        if (result.success) {
            System.exit(0);
        } else {
            System.exit(1);
        }
    }
    
    static class ETLResult {
        boolean success;
        String message;
        int recordsExtracted;
        int recordsTransformed;
        int recordsLoaded;
        LocalDateTime completedAt;
        
        @Override
        public String toString() {
            return String.format("ETLResult{success=%s, extracted=%d, transformed=%d, loaded=%d, message='%s'}",
                    success, recordsExtracted, recordsTransformed, recordsLoaded, message);
        }
    }
}
