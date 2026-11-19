package org.example.util;

import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public final class DatabaseConfig {

        private static final String CONFIG_FILE =
                "/application.properties";

        private static final Pattern ENV_PATTERN =
                Pattern.compile("^\\$\\{([A-Z][A-Z0-9_]*)}$");

        private static final Properties properties = loadProperties();

        private DatabaseConfig() {
        }

        private static Properties loadProperties() {
            Properties config = new Properties();

            try (InputStream input = DatabaseConfig.class
                    .getResourceAsStream(CONFIG_FILE)) {

                if (input == null) {
                    throw new IllegalStateException(
                            "Database configuration file is missing."
                    );
                }

                config.load(input);
                return config;

            } catch (IOException e) {
                throw new IllegalStateException(
                        "Unable to load database configuration.", e
                );
            }
        }

        private static String getRequiredProperty(String key) {
            String value = properties.getProperty(key);

            if (value == null || value.isBlank()) {
                throw new IllegalStateException(
                        "Missing database configuration: " + key
                );
            }

            Matcher matcher = ENV_PATTERN.matcher(value.trim());

            if (matcher.matches()) {
                String variableName = matcher.group(1);
                String environmentValue = System.getenv(variableName);

                if (environmentValue == null ||
                        environmentValue.isBlank()) {
                    throw new IllegalStateException(
                            "Required environment variable is missing: "
                                    + variableName
                    );
                }

                return environmentValue;
            }

            return value.trim();
        }

        public static String getHost() {
            return getRequiredProperty("db.host");
        }

        public static int getPort() {
            String port = getRequiredProperty("db.port");

            try {
                int parsedPort = Integer.parseInt(port);

                if (parsedPort < 1 || parsedPort > 65535) {
                    throw new IllegalArgumentException();
                }

                return parsedPort;

            } catch (IllegalArgumentException e) {
                throw new IllegalStateException(
                        "Invalid database port configuration."
                );
            }
        }

        public static String getDatabaseName() {
            return getRequiredProperty("db.name");
        }

        public static String getUsername() {
            return getRequiredProperty("db.username");
        }

        public static String getPassword() {
            return getRequiredProperty("db.password");
        }

        public static String getSslMode() {
            String sslMode = getRequiredProperty("db.sslMode");

            if (!"VERIFY_IDENTITY".equals(sslMode)) {
                throw new IllegalStateException(
                        "Database TLS identity verification is required."
                );
            }

            return sslMode;
        }
}
