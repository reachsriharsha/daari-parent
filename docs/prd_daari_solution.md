# School Van Tracking Solution - Product Requirements Document (PRD)

**Version:** 1.0  
**Date:** October 28, 2025  
**Status:** Draft - MVP Scope

---

## 1. Executive Summary

### 1.1 Product Overview

A real-time school van tracking solution enabling parents to monitor their children's school commute and drivers to manage trips efficiently. The system consists of three components: Driver Android App, Parent Android App, and a FastAPI-based backend with real-time location tracking and notifications.

### 1.2 Target Users

- **Primary:** Parents of school-going children, School van drivers
- **Secondary:** School administrators (group admins)

### 1.3 Key Objectives

- Provide real-time van location tracking to parents
- Enable drivers to manage trips with automated location sharing
- Send proactive notifications about van arrival times
- Ensure reliable offline functionality for drivers

---

## 2. System Architecture

### 2.1 Components Overview

```
┌─────────────────┐         ┌─────────────────┐
│   Driver App    │         │   Parent App    │
│   (Android)     │         │   (Android)     │
└────────┬────────┘         └────────┬────────┘
         │                           │
         │ REST API / WebSocket      │ REST API / WebSocket
         │                           │
         └───────────┬───────────────┘
                     │
         ┌───────────▼────────────┐
         │   Backend (FastAPI)    │
         │  ┌──────────────────┐  │
         │  │   PostgreSQL     │  │
         │  │   (Data Store)   │  │
         │  └──────────────────┘  │
         │  ┌──────────────────┐  │
         │  │      Redis       │  │
         │  │    (Caching)     │  │
         │  └──────────────────┘  │
         └───────────┬────────────┘
                     │
         ┌───────────▼────────────┐
         │  Firebase Services     │
         │  - Authentication      │
         │  - Cloud Messaging     │
         └────────────────────────┘
```

### 2.2 Technology Stack

**Frontend (Both Apps):**

- Platform: Android (Flutter)
- Local Storage: Hive (offline data persistence)
- Maps: Google Maps API with background tracking
- Authentication: Firebase Authentication (OTP)
- Notifications: Firebase Cloud Messaging (FCM)

**Backend:**

- Framework: FastAPI (Python)
- Database: PostgreSQL
- Cache: Redis
- Authentication: Firebase Admin SDK
- Real-time: WebSocket / Server-Sent Events (SSE)

**Infrastructure:**

- [Placeholder for deployment architecture - Docker/Kubernetes/Cloud provider]

---

## 3. User Roles & Permissions

### 3.1 Role Definitions

| Role       | Capabilities                                                                    | Limitations                               |
| ---------- | ------------------------------------------------------------------------------- | ----------------------------------------- |
| **Parent** | View trip status, receive notifications, member of multiple groups              | Cannot start/stop trips, read-only access |
| **Driver** | Start/stop trips, share real-time location, one driver per group                | Cannot manage group membership            |
| **Admin**  | Create/delete groups, add/remove users, assign admins, manage driver assignment | Max 2 admins per group                    |

### 3.2 Role Assignment Rules

- Any authenticated user can create a group and becomes its admin
- A user can be a Driver in one group and a Parent in another group
- A user CANNOT be both Driver and Parent in the same group
- A user CANNOT be both Driver and Admin in the same group
- Admins can assign other members as admins (max 2 admins total per group)

---

## 4. Core Features & Requirements

### 4.1 Authentication & User Management

#### 4.1.1 User Registration/Login

- **REQ-AUTH-001:** Users authenticate via Firebase OTP (phone number based)
- **REQ-AUTH-002:** First-time users complete profile setup (name, phone, role preference)
- **REQ-AUTH-003:** Session management via Firebase tokens with backend validation
- **REQ-AUTH-004:** Auto-refresh expired tokens

#### 4.1.2 User Profile

- **REQ-USER-001:** User profile stores: name, phone number, user ID
- **REQ-USER-002:** Users can update their profile information
- **REQ-USER-003:** Users can view their group memberships and roles

### 4.2 Group Management

#### 4.2.1 Group Creation

- **REQ-GROUP-001:** Any authenticated user can create a new group
- **REQ-GROUP-002:** Group creation requires: group name, trip type (pickup/dropoff), approximate time
- **REQ-GROUP-003:** Group creator automatically becomes admin
- **REQ-GROUP-004:** Each group represents a single recurring or one-time trip

#### 4.2.2 Group Administration

- **REQ-GROUP-005:** Admins can add users to the group by phone number/user ID
- **REQ-GROUP-006:** Admins can remove users from the group
- **REQ-GROUP-007:** Admins can assign/revoke admin role (max 2 admins per group)
- **REQ-GROUP-008:** Admins can assign exactly one driver to the group
- **REQ-GROUP-009:** Admins can reassign driver role to a different member
- **REQ-GROUP-010:** Admins can delete the group (requires confirmation)

#### 4.2.3 Group Types

- **REQ-GROUP-011:** Groups are categorized as "Pickup" or "Dropoff" trips
- **REQ-GROUP-012:** Separate groups exist for morning pickup and evening dropoff
- **REQ-GROUP-013:** Groups can be marked as recurring (daily/weekly) or one-time

#### 4.2.4 Group Membership

- **REQ-GROUP-014:** Users can be members of multiple groups
- **REQ-GROUP-015:** Users receive invitation notifications when added to a group
- **REQ-GROUP-016:** Users can leave a group voluntarily (except drivers during active trips)

### 4.3 Trip Management (Driver App)

#### 4.3.1 Trip Initiation

- **REQ-TRIP-001:** Driver can start a trip in real-time for their assigned group
- **REQ-TRIP-002:** No advance trip scheduling in MVP
- **REQ-TRIP-003:** Driver confirms trip start, which triggers location tracking
- **REQ-TRIP-004:** Only one active trip allowed per driver at a time

#### 4.3.2 Location Tracking

- **REQ-TRIP-005:** App uses Google Maps Background Location API
- **REQ-TRIP-006:** GPS coordinates sent to backend at 5-meter displacement OR 8-second intervals (whichever comes first)
- **REQ-TRIP-007:** Location updates include: latitude, longitude, timestamp, accuracy, speed, bearing
- **REQ-TRIP-008:** Driver app displays current route on map with trail showing path traveled

#### 4.3.3 Offline Functionality

- **REQ-TRIP-009:** Driver app continues tracking location when offline
- **REQ-TRIP-010:** Location data stored locally in Hive database when offline
- **REQ-TRIP-011:** Queued location data syncs to backend when connection restored
- **REQ-TRIP-012:** App displays offline status indicator to driver

#### 4.3.4 Trip Completion

- **REQ-TRIP-013:** Driver manually ends the trip
- **REQ-TRIP-014:** Trip end triggers notification to backend
- **REQ-TRIP-015:** Location tracking stops upon trip completion
- **REQ-TRIP-016:** Trip data moved from active_trips to completed_trips table

### 4.4 Trip Monitoring (Parent App)

#### 4.4.1 Trip Visibility

- **REQ-PARENT-001:** Parents see list of all groups they belong to
- **REQ-PARENT-002:** Active trips displayed with "Live" indicator
- **REQ-PARENT-003:** Parents can view real-time van location on map for active trips
- **REQ-PARENT-004:** Map shows van icon, route traveled, and parent's home location (if configured)

#### 4.4.2 Real-time Updates

- **REQ-PARENT-005:** Parent app receives location updates via WebSocket/SSE
- **REQ-PARENT-006:** Map updates smoothly as van moves (no jarring jumps)
- **REQ-PARENT-007:** Display estimated time of arrival (ETA) to each parent's home
- **REQ-PARENT-008:** Show van speed and last update timestamp

#### 4.4.3 Home Location Configuration

- **REQ-PARENT-009:** Parents can set their home address/location for each group
- **REQ-PARENT-010:** Home location used for geofencing and ETA calculations
- **REQ-PARENT-011:** Parents can update home location anytime

### 4.5 Notifications System

#### 4.5.1 Trip Start Notifications

- **REQ-NOTIF-001:** All group members receive push notification when driver starts trip
- **REQ-NOTIF-002:** Notification includes: driver name, trip type, start time

#### 4.5.2 Proximity Notifications (Geofencing)

- **REQ-NOTIF-003:** Backend calculates ETA to each parent's home continuously
- **REQ-NOTIF-004:** Parent receives notification when van is 15 minutes away from their home
- **REQ-NOTIF-005:** Parent receives follow-up notifications at 10 min, 5 min intervals
- **REQ-NOTIF-006:** Notifications include: current ETA, van's approximate location
- **REQ-NOTIF-007:** Notifications sent via Firebase Cloud Messaging (FCM)

#### 4.5.3 Pickup/Dropoff Notifications

- **REQ-NOTIF-008:** Parents receive notification when van is approaching their home (15 min prior for pickup)
- **REQ-NOTIF-009:** Parents receive notification when van is approaching their home (15 min prior for dropoff)
- **REQ-NOTIF-010:** No notification sent when trip ends

#### 4.5.4 Notification Management

- **REQ-NOTIF-011:** Users can view notification history in-app
- **REQ-NOTIF-012:** Users can enable/disable notification types in settings
- **REQ-NOTIF-013:** System prevents duplicate notifications for same event

### 4.6 Backend Services

#### 4.6.1 Data Management

- **REQ-BACK-001:** PostgreSQL stores: users, groups, group_members, active_trips, completed_trips, home_locations
- **REQ-BACK-002:** Redis caches: active trip data, user sessions, recent location updates
- **REQ-BACK-003:** Active trip data moved to completed_trips upon trip end
- **REQ-BACK-004:** Completed trips retained for [X days - specify retention policy]

#### 4.6.2 Real-time Processing

- **REQ-BACK-005:** Backend receives location updates from driver app
- **REQ-BACK-006:** Backend broadcasts location updates to all group members via WebSocket/FCM
- **REQ-BACK-007:** Backend calculates ETA using Google Maps Distance Matrix API
- **REQ-BACK-008:** Backend triggers geofencing checks on each location update

#### 4.6.3 Geofencing & ETA Engine

- **REQ-BACK-009:** Create geofence radius around each parent's home (configurable, default 2 km)
- **REQ-BACK-010:** Calculate real-time ETA considering: current location, traffic, route
- **REQ-BACK-011:** Trigger notifications based on ETA thresholds (15 min, 10 min, 5 min)
- **REQ-BACK-012:** Prevent notification spam (max one notification per threshold per trip)

#### 4.6.4 API Endpoints (Placeholder)

```
[PLACEHOLDER - API SPECIFICATIONS TO BE FILLED]

Authentication:
- POST /auth/send-otp
- POST /auth/verify-otp
- POST /auth/refresh-token

User Management:
- GET /users/me
- PUT /users/me
- GET /users/{user_id}

Group Management:
- POST /groups
- GET /groups
- GET /groups/{group_id}
- PUT /groups/{group_id}
- DELETE /groups/{group_id}
- POST /groups/{group_id}/members
- DELETE /groups/{group_id}/members/{user_id}
- PUT /groups/{group_id}/admins
- PUT /groups/{group_id}/driver

Trip Management:
- POST /trips/start
- POST /trips/{trip_id}/end
- POST /trips/{trip_id}/location
- GET /trips/{trip_id}
- GET /trips/active

Parent Services:
- GET /parents/home-location
- PUT /parents/home-location
- GET /parents/trips/active

WebSocket:
- WS /ws/trips/{trip_id}
```

---

## 5. Data Models

### 5.1 Core Entities

#### Users Table

```sql
- user_id (PK)
- phone_number (unique)
- name
- firebase_uid
- created_at
- updated_at
```

#### Groups Table

```sql
- group_id (PK)
- group_name
- trip_type (pickup/dropoff)
- approximate_time
- is_recurring (boolean)
- created_by (FK: user_id)
- created_at
- updated_at
```

#### Group Members Table

```sql
- member_id (PK)
- group_id (FK)
- user_id (FK)
- role (admin/driver/parent)
- joined_at
- UNIQUE(group_id, user_id)
```

#### Active Trips Table

```sql
- trip_id (PK)
- group_id (FK)
- driver_id (FK: user_id)
- start_time
- last_location (JSON: lat, lng, timestamp)
- status (started/paused/ended)
```

#### Completed Trips Table

```sql
- trip_id (PK)
- group_id (FK)
- driver_id (FK)
- start_time
- end_time
- route_data (JSON: array of location points)
- distance_covered
- duration
```

#### Home Locations Table

```sql
- location_id (PK)
- user_id (FK)
- group_id (FK)
- latitude
- longitude
- address
- UNIQUE(user_id, group_id)
```

#### Location History Table (Optional - for analytics)

```sql
- location_id (PK)
- trip_id (FK)
- latitude
- longitude
- accuracy
- speed
- bearing
- timestamp
```

### 5.2 Redis Cache Structure

```
active_trip:{trip_id} -> {trip data, current location}
group_members:{group_id} -> [user_ids with FCM tokens]
user_session:{user_id} -> {auth token, expiry}
location_queue:{trip_id} -> [recent location updates]
notification_sent:{trip_id}:{user_id}:{threshold} -> timestamp
```

---

## 6. User Flows

### 6.1 Driver Flow - Starting a Trip

1. Driver logs in via OTP
2. Driver sees list of groups where they are assigned as driver
3. Driver selects group and taps "Start Trip"
4. App requests location permissions (if not granted)
5. Background location tracking begins
6. Driver sees live map with route trail
7. Backend notifies all group parents that trip started
8. Driver navigates the route
9. Location updates sent every 5m/8s to backend
10. Driver taps "End Trip" when complete
11. Trip data saved to completed_trips

### 6.2 Parent Flow - Monitoring Trip

1. Parent logs in via OTP
2. Parent sees dashboard with all groups
3. Parent sees "Live" indicator on active trip
4. Parent taps on active trip to view map
5. Map shows van location, route, and their home
6. Parent receives notification "Van started - Morning Pickup"
7. Parent receives notification "Van is 15 mins away"
8. Parent receives notifications at 10 min, 5 min intervals
9. Parent monitors real-time location on map
10. Trip ends, map shows final route

### 6.3 Admin Flow - Creating Group

1. Admin logs in and taps "Create Group"
2. Admin enters group name, trip type, time
3. Admin adds members by phone number
4. Admin assigns one member as driver
5. Admin assigns another member as co-admin (optional)
6. Group created, all members receive invitations
7. Admin can later add/remove members or change driver

---

## 7. Non-Functional Requirements

### 7.1 Performance

- **REQ-PERF-001:** Location updates processed within 2 seconds
- **REQ-PERF-002:** Parent app map updates within 3 seconds of location change
- **REQ-PERF-003:** API response time < 500ms for 95th percentile
- **REQ-PERF-004:** Support up to 100 concurrent active trips
- **REQ-PERF-005:** Notification delivery within 5 seconds

### 7.2 Reliability

- **REQ-REL-001:** System uptime of 99.5%
- **REQ-REL-002:** Zero location data loss (offline queue must sync)
- **REQ-REL-003:** Automatic retry mechanism for failed API calls
- **REQ-REL-004:** Graceful degradation when maps API unavailable

### 7.3 Security

- **REQ-SEC-001:** All API requests authenticated via Firebase tokens
- **REQ-SEC-002:** HTTPS/TLS for all network communication
- **REQ-SEC-003:** Rate limiting on API endpoints (100 req/min per user)
- **REQ-SEC-004:** Input validation and sanitization on all endpoints
- **REQ-SEC-005:** Location data encrypted at rest in database

### 7.4 Privacy & Child Safety (MVP - Minimum Compliance)

- **REQ-PRIV-001:** Users consent to location tracking before trip start
- **REQ-PRIV-002:** Location data visible only to group members
- **REQ-PRIV-003:** Parents see only their group's trip data (no cross-group visibility)
- **REQ-PRIV-004:** User data deletion capability (right to be forgotten)
- **REQ-PRIV-005:** No sharing of data with third parties
- **REQ-PRIV-006:** Completed trip data anonymized after [X days]
- **REQ-PRIV-007:** Comply with regional data protection laws (GDPR/COPPA considerations for future)

**Note:** Post-MVP will include comprehensive child safety features, enhanced privacy controls, and full regulatory compliance.

### 7.5 Scalability

- **REQ-SCALE-001:** Database design supports 10,000+ groups
- **REQ-SCALE-002:** Backend horizontally scalable (stateless services)
- **REQ-SCALE-003:** Redis cluster for distributed caching

### 7.6 Usability

- **REQ-UX-001:** App loads within 3 seconds on 4G connection
- **REQ-UX-002:** Maximum 3 taps to start a trip
- **REQ-UX-003:** Clear visual indicators for trip status (live/ended)
- **REQ-UX-004:** Error messages user-friendly and actionable

---

## 8. Deployment Architecture

### 8.1 Infrastructure Components

```
[PLACEHOLDER - TO BE DETAILED]

Suggested Architecture:
- Load Balancer (AWS ALB / GCP Load Balancer)
- FastAPI containers (Docker/Kubernetes)
- PostgreSQL (managed service: AWS RDS / GCP Cloud SQL)
- Redis (managed service: AWS ElastiCache / GCP Memorystore)
- Firebase (Authentication + FCM)
- Google Maps API
- Monitoring: Prometheus + Grafana / Datadog
- Logging: ELK Stack / CloudWatch
```

### 8.2 Deployment Strategy

- **REQ-DEPLOY-001:** Containerized deployment using Docker
- **REQ-DEPLOY-002:** CI/CD pipeline for automated testing and deployment
- **REQ-DEPLOY-003:** Blue-green deployment for zero-downtime updates
- **REQ-DEPLOY-004:** Automated database migrations
- **REQ-DEPLOY-005:** Health check endpoints for monitoring

### 8.3 Monitoring & Observability

- **REQ-MON-001:** Application performance monitoring (APM)
- **REQ-MON-002:** Real-time alerting for critical errors
- **REQ-MON-003:** Dashboard for active trips, users, system health
- **REQ-MON-004:** Log aggregation and searchability

---

## 9. Testing Requirements

### 9.1 Unit Testing

- Minimum 70% code coverage for backend
- Test all API endpoints with various inputs
- Test offline queue mechanism in driver app
- Test geofencing calculations

### 9.2 Integration Testing

- Test Firebase OTP flow end-to-end
- Test location updates from driver to parent app
- Test notification delivery pipeline
- Test offline-to-online sync

### 9.3 User Acceptance Testing

- Test with 10+ real users (drivers and parents)
- Test on different Android devices and OS versions
- Test in varying network conditions (4G/3G/offline)
- Test battery consumption during extended trips

---

## 10. Out of Scope (Post-MVP)

The following features are explicitly excluded from MVP and considered for future releases:

### 10.1 Communication Features

- In-app chat between parents and drivers
- Group messaging
- Voice/video calls

### 10.2 Safety Features

- Emergency SOS button
- Panic alert to all group members
- School/police integration for emergencies

### 10.3 Advanced Features

- Attendance tracking (mark student pickup/dropoff)
- Multiple language support
- Route optimization for drivers
- Fuel/expense tracking
- Driver rating system
- Push-to-talk feature
- Geofence alerts for school arrival

### 10.4 Analytics & Reporting

- Trip history reports
- Distance/time analytics
- Driver performance metrics
- Parent engagement statistics

### 10.5 Compliance & Safety

- Full COPPA compliance
- Enhanced child safety verification
- Background checks integration
- Detailed audit logs

---

## 11. Success Metrics (KPIs)

### 11.1 User Engagement

- Daily active users (DAU)
- Average trips per day
- Parent app session duration during active trips

### 11.2 Technical Performance

- Average location update latency
- Notification delivery success rate (>95%)
- Offline sync success rate (>99%)
- API error rate (<1%)

### 11.3 Business Metrics

- User retention rate (week-over-week)
- Group creation rate
- Average group size

---

## 12. Risks & Mitigation

### 12.1 Technical Risks

| Risk                                   | Impact | Mitigation                                                    |
| -------------------------------------- | ------ | ------------------------------------------------------------- |
| GPS inaccuracy in dense areas          | High   | Use Google Maps Snap to Roads API, implement kalman filtering |
| Battery drain from background tracking | High   | Optimize location update frequency, use adaptive tracking     |
| Firebase cost overruns                 | Medium | Implement message batching, use Redis for filtering           |
| Google Maps API cost                   | Medium | Cache routes, rate limit requests, set budget alerts          |

### 12.2 User Experience Risks

| Risk                       | Impact | Mitigation                                  |
| -------------------------- | ------ | ------------------------------------------- |
| Driver forgets to end trip | Medium | Auto-end after X minutes of no movement     |
| False proximity alerts     | Medium | Implement hysteresis in geofencing logic    |
| Notification fatigue       | Medium | Allow customizable notification preferences |

### 12.3 Business Risks

| Risk                          | Impact | Mitigation                                           |
| ----------------------------- | ------ | ---------------------------------------------------- |
| Low user adoption             | High   | Beta test with target schools, gather feedback early |
| Privacy concerns from parents | High   | Clear privacy policy, transparent data usage         |

---

## 13. Timeline & Milestones (Suggested)

### Phase 1: Foundation (Weeks 1-3)

- Backend API setup with PostgreSQL and Redis
- Firebase authentication integration
- User and group management APIs
- Basic admin panel for testing

### Phase 2: Driver App (Weeks 4-6)

- Driver app UI/UX
- Background location tracking
- Offline data persistence with Hive
- Trip start/end functionality
- Google Maps integration

### Phase 3: Parent App (Weeks 7-9)

- Parent app UI/UX
- Real-time map display
- WebSocket/SSE integration for live updates
- Home location configuration

### Phase 4: Notifications (Weeks 10-11)

- Firebase Cloud Messaging setup
- Geofencing and ETA engine
- Notification triggers and delivery
- Notification preferences

### Phase 5: Testing & Launch (Weeks 12-14)

- End-to-end integration testing
- User acceptance testing with beta users
- Performance optimization
- Bug fixes and polish
- Production deployment

---

## 14. Appendix

### 14.1 Glossary

- **Trip:** A single journey from start to end (pickup or dropoff)
- **Group:** A collection of users (admin, driver, parents) for a specific trip route
- **Active Trip:** A trip currently in progress with live tracking
- **Geofence:** Virtual boundary around a parent's home location
- **ETA:** Estimated Time of Arrival

### 14.2 Reference Documentation

- [Google Maps Platform - Background Location API](https://developers.google.com/maps/documentation/android-sdk/location)
- [Firebase Authentication](https://firebase.google.com/docs/auth)
- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Flutter Hive](https://docs.hivedb.dev/)

### 14.3 Assumptions

1. Users have Android devices with GPS capability
2. Users have data connectivity (4G/WiFi) for real-time tracking
3. Users grant location permissions to apps
4. School trip routes are generally consistent
5. Average trip duration is 30-90 minutes

---

## Document Control

**Prepared By:** [Your Name]  
**Reviewed By:** [Stakeholder Names]  
**Approved By:** [Approver Name]  
**Next Review Date:** [Date]

**Change Log:**
| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | Oct 28, 2025 | [Your Name] | Initial MVP PRD |

---

**End of Document**
