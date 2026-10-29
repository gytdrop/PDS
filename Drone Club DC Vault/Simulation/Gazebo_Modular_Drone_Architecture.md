# Gazebo Modular Drone Architecture & SDF Engineering Reference

## 1. Directory Topology
```text
parts_library/
├── chassis/                 # Central airframe & inertial root
├── t_motor_f60/             # Motor link + rotor link + joint + motor plugin
├── livox_mid360/            # GPU LiDAR sensor module
└── modular_drone/           # Master assembly aggregating sub-models via <include>
```

## 2. Dynamic Assembly Model (`modular_drone/model.sdf`)

```xml
<?xml version="1.0" ?>
<sdf version="1.8">
  <model name="modular_drone">
    <include>
      <uri>model://chassis</uri>
      <name>chassis</name>
      <pose>0 0 0 0 0 0</pose>
    </include>

    <!-- Front Left Motor -->
    <include>
      <uri>model://t_motor_f60</uri>
      <name>motor_fl</name>
      <pose relative_to="chassis::base_link">0.15 0.15 0.03 0 0 0</pose>
    </include>
    <joint name="joint_mount_fl" type="fixed">
      <parent>chassis::base_link</parent>
      <child>motor_fl::motor_base</child>
    </joint>

    <!-- Modular Sensor Payload -->
    <include>
      <uri>model://livox_mid360</uri>
      <name>lidar</name>
      <pose relative_to="chassis::base_link">0.12 0 0.05 0 0.1745 0</pose>
    </include>
    <joint name="joint_mount_lidar" type="fixed">
      <parent>chassis::base_link</parent>
      <child>lidar::livox_base</child>
    </joint>
  </model>
</sdf>
```

## 3. C++ Lifecycle System Execution Flow

* `ISystemConfigure`: Parse configuration XML tags once during SDF loading.
* `ISystemPreUpdate`: Apply thrust ($F = k_T \omega^2$) and aerodynamic drag before physics time-step integration.
* `ISystemPostUpdate`: Extract state observations (IMU poses, odometry) after physics resolution.

## 4. CAD/Blender to SDF Conversion Pipeline

1. **Pivot Alignment**: Snap origin to Link Center of Mass or physical hinge axis (`Object -> Set Origin`).
2. **Transform Freezing**: `Ctrl + A` -> *Apply All Transforms* to prevent unit/scale mismatch.
3. **Inertia Computation**: Calculate moments of inertia ($I_{xx}, I_{yy}, I_{zz}$) using `trimesh` or CAD mass properties:

$$M_{\text{total}} = \sum m_i, \quad \mathbf{r}_{\text{CoM}} = \frac{1}{M_{\text{total}}} \sum m_i \mathbf{r}_i$$

4. **URDF to SDF Translation**:
```bash
gz sdf -p robot.urdf > model.sdf
```
