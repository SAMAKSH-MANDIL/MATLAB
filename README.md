# 🧠 INDITWIN  
## An Automated Road & Traffic Digital Twin Framework using MATLAB RoadRunner

**INDITWIN** is an end-to-end digital twin generation and simulation framework built on **MATLAB RoadRunner**. It enables rapid creation of HD road networks, static scenes, and dynamic traffic scenarios, allowing teams to simulate, iterate, and validate intelligent mobility systems with precision.

This project abstracts complex RoadRunner workflows into modular, reusable MATLAB scripts, making digital twin creation **repeatable, scalable, and automation-friendly**.

---

## 🚀 Key Capabilities

-  Automated HD Map (RRHD) generation  
-  Programmatic road and lane creation  
-  Static scene synthesis (roads + objects)  
-  Dynamic vehicle spawning on valid lanes  
-  Lane-accurate route generation  
-  Scenario validation & simulation execution  
-  Versioned RRHD stack management (undo / rollback)

---

## 🏗️ Architecture Overview

INDITWIN follows a layered digital-twin pipeline:

Road Geometry → HD Map (RRHD) → Scene → Scenario → Simulation

Each stage is controlled via independent MATLAB scripts, enabling **full automation or selective execution**.

---

## 📂 Project Structure
```
INDITWIN/
└── MATLAB-main/
    ├── generateRoadsHdMap.m
    ├── generateStaticScene.m
    ├── spawnVehiclesOnLane.m
    ├── addActorOnLane.m
    ├── runVehicleOnLatestRrhd.m
    ├── importOsmToRoadRunner.m
    ├── getLatestRrhd.m
    ├── pushRrhd.m
    └── undoLastScene.m
```
 ## ⚙️ Prerequisites

Before running **INDITWIN**, ensure you have:

- **MATLAB** (R2021b or newer recommended)
- **MATLAB RoadRunner**
- A valid **RoadRunner Project**
- RoadRunner **MATLAB API access enabled**

---

## 🧩 Core Modules Explained

### 1️⃣ `generateRoadsHdMap.m`

**Purpose**  
Creates a RoadRunner HD Map (RRHD) programmatically from road centerlines.

**Key Features**
- Supports forward & backward lanes  
- Configurable lane width  
- Custom road geometry input  
- Produces reusable RRHD assets  

**Inputs**
- Road center coordinates  
- Lane configuration (forward / backward)  
- Target RRHD name  

---

### 2️⃣ `generateStaticScene.m`

**Purpose**  
Builds a static RoadRunner scene using the latest RRHD.

**What it does**
- Loads the most recent HD map  
- Adds roads and static environment objects  
- Produces a clean, simulation-ready scene  

---

### 3️⃣ `spawnVehiclesOnLane.m`

**Purpose**  
Spawns vehicles only on valid drivable lanes.

**Highlights**
- Automatically selects forward-driving lanes  
- Ensures legal placement  
- Avoids invalid or overlapping spawns  

---

### 4️⃣ `addActorOnLane.m`

**Purpose**  
Creates a fully drivable scenario.

**Functionality**
- Spawns a vehicle actor  
- Builds a route that exactly follows lane geometry  
- Validates the scenario  
- Starts simulation  

 This is the **core scenario execution module**.

---

### 5️⃣ `runVehicleOnLatestRrhd.m`

**Purpose**  
Runs a vehicle simulation using the latest RRHD version.

**Ideal for**
- Rapid testing  
- Continuous scenario validation  
- Automated CI-style simulation runs  

---

### 6️⃣ `importOsmToRoadRunner.m`

**Purpose**  
Imports OpenStreetMap (OSM) data into RoadRunner.

**Use Cases**
- Real-world city modeling  
- Large-scale road network ingestion  
- Digital twin bootstrapping from real maps  

---

### 7️⃣ `getLatestRrhd.m`

**Purpose**  
Fetches the most recent RRHD version from the project stack.

**Benefit**
- Ensures version consistency across scenes and simulations  

---

### 8️⃣ `pushRrhd.m`

**Purpose**  
Maintains an internal RRHD version stack.

**Benefits**
- Version tracking  
- Safe experimentation  
- Scene reproducibility  

---

### 9️⃣ `undoLastScene.m`

**Purpose**  
Rolls back to a previous RRHD state.

**Behavior**
- Pops the latest RRHD  
- Rebuilds scene from previous version  
- Creates an empty scene if stack is exhausted  

> Enables **non-destructive iteration**.

---

## 🔄 Typical End-to-End Workflow

1. Generate HD Map  
2. Build Static Scene  
3. Spawn Vehicles  
4. Create Scenario  
5. Run Simulation  
6. Iterate or Rollback  

### Example Execution Order

```matlab
generateRoadsHdMap(...)
generateStaticScene(...)
spawnVehiclesOnLane(...)
addActorOnLane(...)
```

## 🎯 Use Cases

- Intelligent Transportation Systems (ITS)  
- Autonomous vehicle simulation  
- Smart city digital twins  
- Traffic flow validation  
- Scenario-based ADAS testing  
- Research & academic simulations  

---

## ✨ Why INDITWIN?

-  Fully scripted & reproducible  
-  Scales from toy roads to city networks  
-  Clean separation of concerns  
-  Designed for automation & CI pipelines  
-  RoadRunner-native, not hacked together  

---

## 📌 Best Practices

- Always use `getLatestRrhd` before scene generation  
- Push RRHD versions after major changes  
- Use `undoLastScene` instead of manual deletion  
- Keep lane configurations consistent across runs  

---

## 🧪 Future Enhancements (Suggested)

- Sensor integration (camera, lidar, radar)  
- Multi-agent traffic scenarios  
- Scenario parameter sweeps  
- Simulink co-simulation  
- Automated metrics & KPIs  

---

## 🤝 Contributing

Contributions are welcome!  
Please follow standard MATLAB coding conventions and keep modules independent.

---

## 📬 Contact

For product inquiries, research collaborations, or enterprise integrations,  
please contact the **INDITWIN development team**.
