package org.example.util;

import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.Properties;

public final class DatabaseConnection {

    private DatabaseConnection() {
    }

    public static Connection getConnection()
            throws SQLException {

        String host = DatabaseConfig.getHost();
        int port = DatabaseConfig.getPort();
        String database = DatabaseConfig.getDatabaseName();

        String url = String.format(
                "jdbc:mysql://%s:%d/%s",
                host,
                port,
                database
        );

        Path truststorePath = Path.of(
                System.getProperty("user.home"),
                ".estipendija",
                "aiven-truststore.p12"
        );

        if (!Files.isRegularFile(truststorePath)) {
            throw new IllegalStateException(
                    "Local database TLS truststore is missing."
            );
        }

        String truststorePassword =
                System.getenv("DB_TRUSTSTORE_PASSWORD");

        if (truststorePassword == null ||
                truststorePassword.isBlank()) {
            throw new IllegalStateException(
                    "Required environment variable is missing: "
                            + "DB_TRUSTSTORE_PASSWORD"
            );
        }

        Properties connectionProperties = new Properties();

        connectionProperties.setProperty(
                "user",
                DatabaseConfig.getUsername()
        );

        connectionProperties.setProperty(
                "password",
                DatabaseConfig.getPassword()
        );

        connectionProperties.setProperty(
                "sslMode",
                DatabaseConfig.getSslMode()
        );

        connectionProperties.setProperty(
                "trustCertificateKeyStoreUrl",
                truststorePath.toUri().toString()
        );

        connectionProperties.setProperty(
                "trustCertificateKeyStoreType",
                "PKCS12"
        );

        connectionProperties.setProperty(
                "trustCertificateKeyStorePassword",
                truststorePassword
        );

        connectionProperties.setProperty(
                "fallbackToSystemTrustStore",
                "false"
        );

        connectionProperties.setProperty(
                "connectTimeout",
                "10000"
        );

        connectionProperties.setProperty(
                "socketTimeout",
                "15000"
        );

        return DriverManager.getConnection(
                url,
                connectionProperties
        );
    }
}
