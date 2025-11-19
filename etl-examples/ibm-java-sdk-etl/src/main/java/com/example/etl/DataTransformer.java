package com.example.etl;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

public class DataTransformer {
    private static final Logger logger = LoggerFactory.getLogger(DataTransformer.class);
    
    public List<CustomerRecord> transform(List<CustomerRecord> rawRecords) {
        logger.info("Starting data transformation for {} records", rawRecords.size());
        
        List<CustomerRecord> transformedRecords = rawRecords.stream()
                .filter(this::isValidRecord)
                .map(this::normalizeRecord)
                .map(this::enrichRecord)
                .collect(Collectors.toList());
        
        logger.info("Transformation complete. {} records passed validation and transformation", transformedRecords.size());
        
        return transformedRecords;
    }
    
    private boolean isValidRecord(CustomerRecord record) {
        if (record.getCustomerId() == null || record.getCustomerId().trim().isEmpty()) {
            logger.warn("Skipping record with missing customer ID");
            return false;
        }
        
        if (record.getEmail() == null || !isValidEmail(record.getEmail())) {
            logger.warn("Skipping record {} with invalid email: {}", record.getCustomerId(), record.getEmail());
            return false;
        }
        
        if (record.getFirstName() == null || record.getLastName() == null) {
            logger.warn("Skipping record {} with missing name fields", record.getCustomerId());
            return false;
        }
        
        return true;
    }
    
    private boolean isValidEmail(String email) {
        if (email == null || email.trim().isEmpty()) {
            return false;
        }
        return email.matches("^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$");
    }
    
    private CustomerRecord normalizeRecord(CustomerRecord record) {
        if (record.getFirstName() != null) {
            record.setFirstName(normalizeString(record.getFirstName()));
        }
        
        if (record.getLastName() != null) {
            record.setLastName(normalizeString(record.getLastName()));
        }
        
        if (record.getEmail() != null) {
            record.setEmail(record.getEmail().toLowerCase().trim());
        }
        
        if (record.getPhone() != null) {
            record.setPhone(normalizePhoneNumber(record.getPhone()));
        }
        
        if (record.getZipCode() != null) {
            record.setZipCode(normalizeZipCode(record.getZipCode()));
        }
        
        if (record.getState() != null) {
            record.setState(record.getState().toUpperCase().trim());
        }
        
        if (record.getCountry() != null) {
            record.setCountry(record.getCountry().toUpperCase().trim());
        }
        
        if (record.getStatus() != null) {
            record.setStatus(record.getStatus().toLowerCase().trim());
        }
        
        return record;
    }
    
    private String normalizeString(String value) {
        if (value == null) {
            return null;
        }
        
        value = value.trim();
        
        if (value.isEmpty()) {
            return null;
        }
        
        return value.substring(0, 1).toUpperCase() + value.substring(1).toLowerCase();
    }
    
    private String normalizePhoneNumber(String phone) {
        if (phone == null) {
            return null;
        }
        
        String cleaned = phone.replaceAll("[^0-9]", "");
        
        if (cleaned.length() == 10) {
            return String.format("%s-%s-%s", 
                    cleaned.substring(0, 3), 
                    cleaned.substring(3, 6), 
                    cleaned.substring(6));
        } else if (cleaned.length() == 11 && cleaned.startsWith("1")) {
            return String.format("+1-%s-%s-%s", 
                    cleaned.substring(1, 4), 
                    cleaned.substring(4, 7), 
                    cleaned.substring(7));
        }
        
        return phone;
    }
    
    private String normalizeZipCode(String zipCode) {
        if (zipCode == null) {
            return null;
        }
        
        String cleaned = zipCode.replaceAll("[^0-9]", "");
        
        if (cleaned.length() == 5) {
            return cleaned;
        } else if (cleaned.length() == 9) {
            return cleaned.substring(0, 5) + "-" + cleaned.substring(5);
        }
        
        return zipCode;
    }
    
    private CustomerRecord enrichRecord(CustomerRecord record) {
        if (record.getStatus() == null || record.getStatus().isEmpty()) {
            record.setStatus("active");
            logger.debug("Set default status 'active' for customer {}", record.getCustomerId());
        }
        
        if (record.getCountry() == null || record.getCountry().isEmpty()) {
            record.setCountry("USA");
            logger.debug("Set default country 'USA' for customer {}", record.getCustomerId());
        }
        
        if (record.getTotalPurchases() == null) {
            record.setTotalPurchases(0.0);
        }
        
        return record;
    }
}
