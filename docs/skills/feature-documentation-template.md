# Feature Documentation Template

> ### About this document
>
> A **fill-in template**, not a guide — substitute `{{FEATURE_NAME}}` and work
> through it to produce a feature documentation package.
>
> [../feature/authentication/](../feature/authentication/) is the worked output
> of this template and the standard to match. Before using it, read
> [../feature/README.md](../feature/README.md#standard-feature-document-set) —
> it says which documents to create and, more importantly, which to skip.
> **Do not generate a file that would have no real content in it.**

# PARAMETERS
# ============================================================

FEATURE_NAME = {{FEATURE_NAME}}

# Examples

FEATURE_NAME = Depots
FEATURE_NAME = Authentication
FEATURE_NAME = My Visit
FEATURE_NAME = Orders
FEATURE_NAME = Quotation
FEATURE_NAME = Lead
FEATURE_NAME = Profile

# ============================================================
# READ FIRST
# ============================================================

Before doing anything, read:

- AI_ENGINEERING_PLAYBOOK.md
- CLAUDE.md
- ENGINEERING_STANDARD.md
- OFFLINE_FIRST_ARCHITECTURE.md

Then use Graphify to analyze the entire feature before generating documentation.

Never assume implementation details.

Everything must be generated from the actual codebase.

============================================================
ROLE
============================================================

Act as:

• Principal Software Architect
• Enterprise Solution Architect
• Senior Product Manager
• Senior Business Analyst
• Senior QA Engineer
• Senior Technical Writer
• Enterprise Documentation Specialist

Your responsibility is to completely document the feature:

{{FEATURE_NAME}}

using the actual Flutter implementation.

This documentation should become the project's official Blueprint.

============================================================
STEP 1
GRAPHIFY ANALYSIS
============================================================

Use Graphify to explore the feature.

Analyze:

lib/features/{{FEATURE_NAME}}

Find

✓ Screens

✓ Widgets

✓ Bloc/Cubit

✓ Events

✓ States

✓ Repository

✓ UseCases

✓ Entities

✓ Models

✓ Remote Datasource

✓ Local Datasource

✓ Drift Tables

✓ Hive Storage

✓ API Calls

✓ Navigation

✓ Offline Flow

✓ Sync Flow

✓ Dependencies

✓ Shared Components

✓ Theme Usage

✓ Localization

✓ Security

Generate a dependency graph.

Do NOT generate documentation until the analysis is complete.

============================================================
STEP 2
CHECK EXISTING DOCUMENTS
============================================================

Search the project for existing documentation.

Examples

Blueprint

Architecture

README

ADR

Feature Spec

Technical Design

Flow Document

API Spec

QA

UAT

Testing Guide

User Guide

If documentation already exists:

Review it.

Update it.

Improve it.

Avoid duplication.

If no documentation exists:

Create a complete documentation package.

============================================================
DOCUMENTS TO GENERATE
============================================================

Generate ALL of the following.

------------------------------------------------------------
1. FEATURE BLUEPRINT
------------------------------------------------------------

docs/features/{{FEATURE_NAME}}/

Blueprint.md

Include

Purpose

Business Goal

Problem Statement

Objectives

Business Value

Target Users

Roles

Permissions

Dependencies

Architecture

Feature Scope

Out of Scope

Future Roadmap

KPIs

Success Metrics

============================================================
2. FEATURE ARCHITECTURE
============================================================

Architecture.md

Explain

Presentation Layer

Domain Layer

Data Layer

Repositories

Datasource

Offline Storage

Sync Queue

API

Navigation

Bloc Flow

Dependency Injection

Security

Performance

Theme

Localization

============================================================
3. FEATURE WORKFLOW
============================================================

Workflow.md

Include

User Journey

Happy Path

Alternative Flow

Offline Flow

Online Flow

Sync Flow

Resume Flow

Error Flow

Navigation Diagram

State Diagram

Sequence Diagram

============================================================
4. FEATURE EXPLANATION
============================================================

Overview.md

Explain

What is this feature?

Why does it exist?

Who uses it?

When is it used?

Business benefits

Technical benefits

Offline behavior

SAP interaction

Security considerations

============================================================
5. TECHNICAL DESIGN
============================================================

Technical_Design.md

Document

Folder Structure

Entities

Models

Repositories

Bloc

UseCases

Datasources

Mapper

Drift

Hive

Secure Storage

Dependency Graph

============================================================
6. API DOCUMENTATION
============================================================

API.md

List

Endpoints

Headers

Authentication

Request

Response

Error Codes

Timeout

Retry

Offline Behavior

Caching

============================================================
7. DATABASE DOCUMENTATION
============================================================

Database.md

Document

Drift Tables

Hive Boxes

Relationships

Indexes

Foreign Keys

Cache

Retention Policy

Cleanup Policy

============================================================
8. SECURITY DOCUMENTATION
============================================================

Security.md

Explain

Authentication

Authorization

Role Permissions

Secure Storage

Token Flow

Encryption

Input Validation

Offline Security

Sensitive Data

============================================================
9. TESTING DOCUMENTATION
============================================================

QA_Test_Plan.md

Generate comprehensive QA.

Include

Smoke Test

Regression Test

Integration Test

Offline Test

Online Test

Theme Test

Localization Test

Performance Test

Security Test

Recovery Test

============================================================
10. UAT DOCUMENT
============================================================

UAT.md

Generate complete User Acceptance Testing.

For every screen create:

------------------------------------------------

Test ID

Title

Precondition

Steps

Expected Result

Actual Result

Status

Priority

Severity

------------------------------------------------

Cover

Happy path

Negative

Offline

Online

Sync

Validation

Permission

Theme

Localization

Performance

Recovery

============================================================
11. USE CASE DOCUMENT
============================================================

UseCases.md

Generate

Actor

Goal

Trigger

Preconditions

Main Flow

Alternative Flow

Exception Flow

Business Rules

Post Conditions

============================================================
12. BUSINESS RULE DOCUMENT
============================================================

BusinessRules.md

Document

Validation Rules

Workflow Rules

Permissions

Offline Rules

Sync Rules

Deletion Rules

Retention Rules

SAP Rules

============================================================
13. CHANGE LOG
============================================================

Changelog.md

Generate

Version

Date

Author

Changes

Migration Notes

Breaking Changes

============================================================
14. IMPLEMENTATION CHECKLIST
============================================================

Implementation_Checklist.md

Checklist

Architecture

Repository

Bloc

UI

Theme

Localization

Offline

Sync

Security

Testing

Documentation

============================================================
15. FUTURE IMPROVEMENTS
============================================================

Roadmap.md

Suggest

UX Improvements

Performance

Architecture

Offline

Security

Automation

Analytics

AI Features

============================================================
QA REQUIREMENTS
============================================================

Generate more than 50 test cases where applicable.

Cover

Normal

Boundary

Invalid

Offline

Synchronization

Permission

Token Expiration

Dark Theme

Light Theme

Tablet

Phone

Landscape

Accessibility

============================================================
OUTPUT STYLE
============================================================

Professional.

Enterprise.

Easy for:

Developers

QA

Business Analysts

Project Managers

SAP Team

UI Designers

Future Engineers

============================================================
SUCCESS CRITERIA
============================================================

Deliver a complete documentation package that could be handed to a new engineering team without requiring code exploration.

Every statement must be based on the actual implementation discovered through Graphify.

If implementation differs from business intent, clearly document:

• Current Implementation
• Intended Behavior
• Gap Analysis
• Recommended Improvements

Do not invent functionality.

Always verify against the codebase first.