# Task: Build a Static Inventory Availability Survey Prototype in SteelForce Mobile

Act as a Senior Flutter Engineer and UI/UX Designer specializing in premium enterprise B2B mobile applications, steel distribution, and construction-material inventory workflows.

## 1. Project Context

You are working in my existing SteelForce Flutter mobile application for ISI Steel.

The app is used by Sales Representatives to visit customer depots, manage customers, quotations, orders, and sales activities.

I need to prototype a new feature called **Inventory Availability Survey**. This feature allows Sales Representatives to photograph visible inventory at a customer depot after checking in. The future version will use AI to analyze images and generate an inventory report.

**For this task, implement the frontend prototype only.**

I want to run the application locally and demonstrate the complete user flow to stakeholders before backend and AI integration.

## 2. Critical Constraints

- First inspect the existing Flutter project structure, routing, theme, design system, state management, reusable widgets, and current depot visit/check-in flow.
- Follow the existing architecture and coding conventions.
- Implement this feature inside the appropriate existing feature/module.
- Do not rebuild the application or replace its architecture.
- Do not modify unrelated features.
- Do not connect to APIs, databases, Firebase, SAP, or external AI services.
- Do not require environment variables or network connectivity.
- Use static mock data and local in-memory state.
- Use the existing camera/image-picker functionality if it already exists and is suitable. Otherwise, create a demo-friendly image capture experience using local mock images or a simulated capture screen.
- Do not claim that real AI analysis or image uploads are happening.
- Preserve existing functionality, navigation, localization, and theme behavior.

Before coding, inspect the project and provide a short implementation plan. Then implement the feature.

## 3. User Story

As a Sales Representative visiting a customer depot, I want to capture at least three photos of the depot's visible stock so that I can review the captured evidence and preview how an AI-generated inventory availability report will appear.

## 4. Required Static User Flow

Implement the following complete flow using the existing navigation conventions.

### Screen 1: Depot Visit / Inventory Availability Entry

Provide a realistic entry point from the existing depot visit or check-in workflow.

Display static demo information:
- Customer: BRANCH OF GEMVAXZIO CO., LTD
- Survey: Inventory Availability
- Status: Required
- Description: Capture photos of the depot's visible stock.
- Progress: Not started, In progress, or Completed.

If the existing application already has a depot detail or check-in screen, integrate the entry point there without breaking the current workflow.

Otherwise, provide an isolated demo entry screen or route that can be opened easily during development.

### Screen 2: Inventory Availability Survey Introduction

Display:
- Customer/depot name.
- Survey title and short instructions.
- Three required photo categories.
- A progress indicator: 0 of 3 photos captured.
- A clear Start Survey button.

Required photo categories:

1. Depot Overview
   - Capture the overall depot and visible stock arrangement.
2. Product & Bundle Details
   - Capture steel bar ends, bundles, product labels, sizes, or markings where available.
3. Additional Stock Area
   - Capture another stock section, warehouse area, or different angle.

Explain that additional photos can be captured when stock is distributed across multiple areas.

### Screen 3: Photo Capture

Create a polished mobile photo capture experience.

Display:
- Camera preview or a demo camera placeholder.
- Current photo category and capture instructions.
- Progress such as Photo 1 of 3.
- Capture Photo action.
- Cancel/back action.
- Optional flash or camera-switch controls only if supported by the existing implementation.

For the static prototype, allow users to simulate taking a photo without connecting to an external service.

If suitable local demo images already exist, use them. Otherwise, create a clearly identified demo placeholder or a simple simulated capture view. Do not invent network image dependencies.

After capturing an image, navigate to the photo review screen.

### Screen 4: Photo Review

Display the captured image or demo placeholder.

Provide:
- Photo category.
- Retake Photo action.
- Use Photo / Save Photo action.
- Next required photo guidance.

Retaking a photo should replace the previous image for that category instead of creating an accidental duplicate.

After saving the image, return to the survey checklist and update the progress.

### Screen 5: Survey Checklist

Show all three required photo categories as individual cards.

Each card should include:
- Category title.
- Short instruction.
- Captured image thumbnail or demo placeholder.
- Status: Required or Captured.
- Retake or Replace action.

Display progress dynamically:
- 0/3 photos.
- 1/3 photos.
- 2/3 photos.
- 3/3 photos.

Allow the user to capture categories in any order.

Add an **Add Another Stock Area** action for optional additional photos. These should not increase the required-photo count beyond the three mandatory categories.

Allow optional photos to be retaken or removed.

Keep the main Submit Survey button disabled until all three required categories have captured images.

### Screen 6: Survey Submission Confirmation

Once all required photos are captured, allow the user to select Submit Survey.

Because this is a static prototype:
- Do not upload any images.
- Do not make API calls.
- Do not invoke an AI model.
- Simulate submission locally.
- Show a success state with the survey reference and submission time generated locally.
- Clearly label the operation as a demo submission if necessary.

Provide a Continue to Inventory Report action.

### Screen 7: Mock AI Processing

Create a short, interactive mock processing screen that previews the intended future experience.

Show illustrative processing stages:
1. Reviewing captured images.
2. Identifying visible materials.
3. Preparing inventory observations.
4. Generating the inventory report.

Use an explicit Continue or Simulate Completion action rather than requiring real background processing or artificial delays.

Clearly label the screen: **Demo AI Processing — No Real AI Analysis**.

### Screen 8: Mock Inventory Availability Report

Create a realistic report screen using static sample data.

Header:
- Inventory Availability Report.
- Customer/depot name.
- Survey reference.
- Report status: Demo Report.
- Submission date/time.

Include the following sections:

**A. Survey Summary**
- Total required photos: 3.
- Captured required photos: 3.
- Optional photos: actual demo count.
- Survey completion status.

**B. Detected Materials — Mock Data**

Use illustrative results such as:
- Reinforcing steel bars.
- Steel bundles.
- Other visible construction materials.

For each sample finding, display:
- Material/category.
- Illustrative estimated quantity or “Unable to estimate”.
- Unit, if applicable.
- Confidence category such as High, Medium, Low, or Requires Verification.
- Source photo reference.

All findings must be clearly marked as static demonstration data. Do not represent them as actual AI detections or confirmed stock balances.

**C. Inventory Observations**
- Visible stock areas.
- Product labels or markings visible in the sample.
- Areas that may need additional photographs.
- Materials requiring manual verification.

**D. Captured Photo Evidence**
- Display all three required photos.
- Allow users to open a photo preview.

**E. Important Disclaimer**

“AI estimates shown in this demonstration are illustrative only. Actual visible inventory, exact quantities, and available-to-sell stock have not been verified.”

Provide a Back to Survey action so users can revisit the prototype.

## 5. Design Requirements

Follow the existing SteelForce design system and reuse the project's theme, typography, color tokens, and components.

Design direction:
- Premium enterprise B2B application.
- Modern, clean, professional, and practical for Sales Representatives working at physical depots.
- Strong visual hierarchy.
- Consistent spacing and alignment.
- Rounded cards and subtle borders.
- Clear status indicators.
- Accessible text contrast.
- Touch-friendly buttons.
- Responsive layouts that work on common Android phones.
- Support light and dark themes if the existing app supports both.
- Keep the existing Khmer/English localization approach if available.

Avoid:
- Excessive gradients.
- Excessive animations.
- Decorative elements that distract from the survey.
- Overly complicated camera screens.
- Unnecessary new dependencies.
- Fake API integrations.
- Breaking the existing navigation or app shell.

The experience should feel like a production-ready feature, even though all data and processing are mocked.

## 6. Functional Requirements

Implement real frontend interactions using the project's existing state-management approach.

The prototype must support:
- Starting a survey.
- Navigating between survey steps.
- Capturing or simulating a photo for each category.
- Reviewing and retaking photos.
- Tracking required-photo completion.
- Adding and removing optional photos.
- Enabling submission only when all three required photos are present.
- Simulating successful submission.
- Viewing the mock processing screen.
- Viewing the static inventory report.
- Returning to the survey without losing captured in-memory state.

Use the existing state-management solution. If the app uses BLoC, follow its established conventions rather than introducing another state-management library.

Keep mock data clearly separated from widgets where appropriate, so real API and AI integration can be introduced later.

## 7. Technical Requirements

- Inspect the repository before editing.
- Follow existing feature-first and Clean Architecture conventions.
- Reuse existing shared widgets and theme tokens.
- Keep responsibilities separated between screens, widgets, state, and mock data.
- Avoid unnecessary abstractions and excessive file creation.
- Use meaningful naming and null-safe Dart.
- Ensure the feature builds without backend configuration.
- Do not edit unrelated business logic.
- Do not add production API interfaces solely for this prototype.
- Do not commit changes or push branches.

After implementation:
1. Run `dart format` on changed Dart files.
2. Run `flutter analyze` or the project's established analysis command.
3. Run relevant existing tests.
4. Fix issues introduced by this feature.
5. Summarize the files changed and any limitations.

## 8. Definition of Done

The task is complete when I can run the existing SteelForce app and demonstrate:

Depot Visit → Start Inventory Survey → Capture 3 Required Photos → Review/Retake → Checklist → Submit Demo Survey → Mock AI Processing → Inventory Availability Report.

All interactions must work locally with static data and no API dependency.

**Priority:** Complete the end-to-end static user flow first. Do not implement backend integration, AI scanning, SAP changes, or production image uploading as part of this task.