# 🚀 CI/CD Guide

> Enterprise Continuous Integration & Continuous Deployment for the Flutter CRM Application

> ### ⚠ Aspirational — most of this is not built (verified 2026-08-27)
>
> This document describes the *intended* pipeline. What actually exists is **one
> workflow**, `.github/workflows/deploy-web.yml`, which builds Flutter Web and
> publishes it to GitHub Pages from the `web` branch.
>
> Specifically **not** present: any `fastlane/` directory, any PR workflow
> running `flutter analyze` / `flutter test` / `dart format`, and the
> `develop` / `release/*` / `hotfix/*` branches (only `main` and `web` exist).
> Android release signing *is* wired in `android/app/build.gradle.kts`, but is
> invoked manually.
>
> Read this as the target. [README.md](README.md) states what is real today.


---

# Overview

This document defines the Continuous Integration (CI) and Continuous Deployment (CD) workflow used by this Flutter CRM application.

Our CI/CD pipeline automates:

* Code Quality
* Testing
* Security
* Build Verification
* Release Packaging
* Beta Distribution
* Production Deployment

The primary goals are to:

* Reduce manual work
* Deliver reliable releases
* Detect issues early
* Maintain consistent code quality
* Improve deployment speed
* Protect production environments

---

# Technology Stack

| Tool                      | Purpose                |
| ------------------------- | ---------------------- |
| GitHub                    | Source Control         |
| GitHub Actions            | Continuous Integration |
| Fastlane                  | Deployment Automation  |
| Firebase App Distribution | Internal Testing       |
| Google Play Console       | Android Release        |
| App Store Connect         | iOS Release            |

Future support:

* Codemagic
* Xcode Cloud

---

# CI/CD Architecture

```text
Developer

↓

Git Commit

↓

GitHub Repository

↓

Pull Request

↓

GitHub Actions

├── Flutter Analyze
├── Dart Format Check
├── Unit Tests
├── Widget Tests
├── Integration Tests
├── Security Scan
├── Dependency Scan
├── Secret Scan
├── Build Android
└── Build iOS

↓

Artifacts

↓

Fastlane

├── Firebase Distribution
├── Google Play Internal Testing
└── TestFlight

↓

QA Team

↓

Production Release
```

---

# Branch Strategy

```text
main
│
├── develop
│
├── feature/*
├── release/*
├── hotfix/*
└── bugfix/*
```

## Branch Rules

### main

Production-ready code only.

Deployments:

* Google Play Production
* Apple App Store

---

### develop

Main development branch.

Deployments:

* Firebase App Distribution

---

### feature/*

Used for individual feature development.

Examples:

```text
feature/leads
feature/depot
feature/visit
feature/revenue
feature/offline-sync
```

---

### release/*

Release preparation.

Example

```text
release/v1.0.0
```

---

### hotfix/*

Emergency production fixes.

---

# Pull Request Workflow

Every Pull Request must pass:

* Flutter Analyze
* Dart Format Check
* Unit Tests
* Widget Tests
* Security Scan
* Dependency Audit
* Build Verification

No Pull Request may be merged if any required check fails.

---

# Continuous Integration

Every push automatically performs:

## Code Quality

* flutter analyze
* dart format
* lint checks

---

## Testing

* Unit Tests
* Widget Tests
* Integration Tests

---

## Build Verification

Android

* Debug APK
* Release APK
* Release AAB

iOS

* IPA Build

---

## Security

Automatically check for:

* Hardcoded secrets
* Vulnerable dependencies
* Insecure packages
* Debug code in release

---

# Continuous Deployment

Deployment is automated according to the target branch.

## develop

Deploy to:

* Firebase App Distribution

Audience:

* Developers
* QA Team

---

## release/*

Deploy to:

* Google Play Internal Testing
* TestFlight

Audience:

* Internal Testers

---

## main

Deploy to:

* Google Play Production
* Apple App Store

---

# Versioning

Use Semantic Versioning.

```
MAJOR.MINOR.PATCH

Example

1.0.0
1.1.0
1.1.1
2.0.0
```

Rules

MAJOR

Breaking changes.

MINOR

New functionality.

PATCH

Bug fixes.

---

# Environment Configuration

Development

```text
.env.development
```

Staging

```text
.env.staging
```

Production

```text
.env.production
```

Never commit sensitive values to the repository.

---

# Secrets Management

Secrets must never be stored in Git.

Store them securely using:

* GitHub Secrets
* Fastlane Match
* Firebase Service Accounts
* Apple Certificates

Examples:

* API Keys
* Signing Keys
* Keystore Passwords
* App Store Credentials
* Google Play Credentials

---

# Fastlane

Fastlane is responsible for deployment automation.

Android

* Build
* Sign
* Upload to Google Play

iOS

* Build
* Archive
* Upload to TestFlight
* Submit to App Store

---

# Release Flow

```text
Developer

↓

Merge into develop

↓

CI Pipeline

↓

Firebase Distribution

↓

QA Testing

↓

Create release branch

↓

Internal Testing

↓

Merge into main

↓

Production Release
```

---

# GitHub Actions Responsibilities

GitHub Actions is responsible for:

* Installing Flutter SDK
* Restoring cache
* Running analysis
* Executing tests
* Building Android
* Building iOS
* Uploading artifacts

Deployment is delegated to Fastlane.

---

# Required GitHub Secrets

Examples:

```text
ANDROID_KEYSTORE

ANDROID_KEY_ALIAS

ANDROID_KEYSTORE_PASSWORD

ANDROID_KEY_PASSWORD

PLAY_STORE_JSON

APP_STORE_CONNECT_KEY

FASTLANE_PASSWORD

FIREBASE_TOKEN
```

---

# Quality Gates

A build fails if:

* Flutter Analyze fails
* Tests fail
* Build fails
* Security scan fails
* Secrets are detected
* Formatting fails

---

# Release Checklist

Before every release:

* Version updated
* Changelog completed
* Tests passed
* Security scan passed
* Release build verified
* Signing verified
* Firebase testing completed
* QA approval received

---

# Future Improvements

Planned enhancements:

* Automatic changelog generation
* Automatic version bump
* Automatic release notes
* Slack notifications
* Microsoft Teams notifications
* Performance testing
* Crash reporting integration
* Code coverage reporting
* SonarQube integration
* Dependency update automation

---

# References

* Flutter Continuous Delivery
* GitHub Actions Documentation
* Fastlane Documentation
* Firebase App Distribution
* Google Play Console
* Apple App Store Connect

---

# Maintainers

Mobile Engineering Team

Version: 1.0.0

Status: Enterprise Standard
