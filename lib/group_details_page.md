# 📱 GroupDetailsPage Visual Component Map

This document provides a visual breakdown of all the UI components and their corresponding functions in the `GroupDetailsPage` Flutter widget.

## 🏗️ **Main Structure**

```
GroupDetailsPage (StatefulWidget)
├── AppBar
│   └── Title: widget.groupName
├── Column (Main body)
│   ├── Search Section
│   ├── Button Section (2 rows)
│   ├── Route Info Panel (conditional)
│   └── Google Map (expanded)
```

---

## 🔍 **Search Section**

```
┌─────────────────────────────────────────────────────┐
│  [TextField: "Search location"] [Search Button]     │
└─────────────────────────────────────────────────────┘
```

**Components → Functions:**

- **TextField** (`_searchController`) → Calls `_searchAndNavigate()` on submit
- **"Search" Button** → Calls `_searchAndNavigate()`

**What `_searchAndNavigate()` does:**

- Takes text from search field
- Converts address to coordinates using `locationFromAddress()`
- Moves map camera to found location
- Sets `_pickedLocation` to the found coordinates

---

## 🎛️ **Button Section (Row 1)**

```
┌──────────────┬──────────────┬──────────────┐
│ "To School"  │ "Finish"     │ "Set Address"│
│   Button     │  Button      │   Button     │
└──────────────┴──────────────┴──────────────┘
```

**Button → Function Mapping:**

### 1. **"To School" Button** → Calls `_startTrip()`

- **When enabled:** When `_tripActive` is false
- **What it does:**
  - Checks location permissions
  - Gets current GPS position
  - Calls backend API to start trip tracking
  - Starts live location updates (`_startLocationTracking()`)
  - Starts 30-second update timer
  - Updates map with route display

### 2. **"Finish" Button** → Calls `_sendTripUpdate("finish")`

- **When visible:** Only when `_tripActive` is true
- **What it does:**
  - Sends trip completion to backend
  - Stops location tracking (`_stopLocationTracking()`)
  - Cancels update timer
  - Clears route display from map

### 3. **"Set Address" Button** → Calls inline async function

- **What it does:**
  - Checks if location is picked on map
  - Sends picked location to backend as group address
  - Shows API response in dialog

---

## 🎛️ **Button Section (Row 2)**

```
┌──────────────────┬──────────────────┐
│ "My Location"    │ "Show Route"     │
│    Button        │    Button        │
└──────────────────┴──────────────────┘
```

**Button → Function Mapping:**

### 4. **"My Location" Button** → Calls `_getCurrentLocation()` + camera animation

- **What it does:**
  - Gets current GPS position
  - Moves map camera to current location
  - Zooms to level 16

### 5. **"Show Route" Button** → Calls `_fitMapToRoute()`

- **When visible:** Only when trip is active AND both locations exist
- **What it does:**
  - Calculates bounds to fit both current and destination locations
  - Animates camera to show entire route

---

## 📊 **Route Info Panel (Conditional)**

```
┌─────────────────────────────────────────────────────┐
│  📏 Distance  │  ⏰ Duration  │  📍 Status        │
│    "X km"     │    "X min"    │  "Tracking/Ready"  │
└─────────────────────────────────────────────────────┘
```

- **When visible:** Only when `_routeInfo` exists AND `_tripActive` is true
- **No clickable functions** - Display only

---

## 🗺️ **Google Map**

```
┌─────────────────────────────────────────────────────┐
│                                                     │
│           [Interactive Google Map]                  │
│              • Markers                              │
│              • Route lines                          │
│              • Tap to set destination               │
│                                                     │
└─────────────────────────────────────────────────────┘
```

**Map Interactions → Functions:**

- **Tap anywhere on map** → Sets `_pickedLocation`

  - Updates destination marker
  - If trip is active: calls `_updateMarkersAndRoute()`
  - If trip not active: just updates markers

- **Map creation** → Sets `_mapController`

---

## 🔄 **Background Functions (Auto-triggered)**

These functions run automatically, not from button presses:

### 1. **`_startLocationTracking()`** - Runs when trip starts

- Listens to GPS position changes every 10 meters
- Auto-updates `_currentLocation`
- Auto-calls `_updateMarkersAndRoute()`

### 2. **`_updateMarkersAndRoute()`** - Called when locations change

- Fetches route from Google Directions API
- Updates map polylines (route path)
- Updates markers (current + destination)
- Calculates route info (distance/duration)

### 3. **Timer callback** - Runs every 30 seconds during active trip

- Calls `_sendTripUpdate("update")`
- Sends location updates to backend

---

## 🎯 **Key State Variables**

| Variable            | Purpose                                      |
| ------------------- | -------------------------------------------- |
| `_tripActive`       | Controls which buttons are enabled/visible   |
| `_pickedLocation`   | Where user tapped on map (destination)       |
| `_currentLocation`  | User's current GPS position                  |
| `_tripId`           | Backend trip identifier                      |
| `_tripName`         | Name of the current trip                     |
| `_routePoints`      | List of coordinates for route polyline       |
| `_markers`          | Map markers (current location + destination) |
| `_polylines`        | Route lines drawn on map                     |
| `_routeInfo`        | Contains distance and duration data          |
| `_mapController`    | Controls map camera and animations           |
| `_searchController` | Controls search text input                   |

---

## 🔄 **Function Flow Diagram**

```
User Interaction Flow:

1. Search Location:
   TextField/Search Button → _searchAndNavigate() → Update map position

2. Start Trip:
   "To School" Button → _startTrip() → Check permissions → API call → _startLocationTracking()

3. During Trip:
   Auto GPS updates → _updateMarkersAndRoute() → Update UI
   Every 30s → _sendTripUpdate("update") → Backend sync

4. Finish Trip:
   "Finish" Button → _sendTripUpdate("finish") → _stopLocationTracking() → Clear UI

5. Map Interaction:
   Tap map → Set _pickedLocation → Update markers/route

6. Utility Functions:
   "My Location" → _getCurrentLocation() → Center map
   "Show Route" → _fitMapToRoute() → Fit camera to route bounds
```

---

## 🚀 **Key Flutter Concepts Used**

1. **StatefulWidget** - Manages changing state (location, trip status)
2. **setState()** - Updates UI when state changes
3. **Controllers** - Manages text input and map controls
4. **Streams** - Live location updates via `Geolocator.getPositionStream()`
5. **Timers** - Periodic backend updates
6. **Async/Await** - Handles API calls and GPS operations
7. **Conditional Rendering** - Shows/hides UI elements based on state

This flow helps understand: **UI Component** → **Function Call** → **What Happens**! Each button has a specific purpose in the trip tracking workflow.
