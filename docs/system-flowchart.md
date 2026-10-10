# Barangay Events System Flowchart

This document provides a clear Mermaid flowchart for the main process of the Barangay Events system, including the roles of citizen, LGU, and super admin.

## Main Process Flow

```mermaid
flowchart TD
    A[Citizen opens the app] --> B{Has account?}
    B -- Yes --> C[Login]
    B -- No --> D[Create account]
    C --> E[View calendar and events]
    D --> E

    E --> F[Browse public or group events]
    F --> G[Join a group or view event details]
    G --> H[Create, update, or comment on an event]
    H --> I[Submit event for review]

    I --> J[LGU reviews the event]
    J --> K{Approved?}
    K -- Yes --> L[Publish event to the calendar]
    K -- No --> M[Return for revision]
    M --> H

    L --> N[Notify citizens through real-time updates]
    N --> O[Citizens receive updates and respond]

    P[LGU logs in] --> Q[Manage events, locations, and announcements]
    Q --> R[Approve or reject citizen submissions]
    R --> S[Publish official barangay activities]

    T[Super Admin logs in] --> U[Manage admin accounts]
    U --> V[Create or update LGU/admin roles]
    V --> W[Monitor access and system settings]

    E --> X[Supabase backend + notifications]
    Q --> X
    U --> X
    X --> Y[Real-time updates to app users]
    Y --> E
    Y --> P
    Y --> T
```

## Role Summary

- Citizen: opens the app, views events, joins groups, submits events, and receives updates.
- LGU: reviews submissions, manages official events, locations, and announcements.
- Super Admin: manages user roles, admin accounts, and overall system access.

## Suggested Presentation Note

This flow shows how the app connects everyday citizens, LGU staff, and administrators through one shared system for coordination, approval, and communication.
