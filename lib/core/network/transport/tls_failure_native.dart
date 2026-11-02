import 'dart:io';

/// See `tls_failure.dart`. `HandshakeException` extends `TlsException`;
/// `CertificateException` is raised for a certificate the platform rejects.
bool isTlsFailure(Object? error) =>
    error is TlsException || error is CertificateException;
