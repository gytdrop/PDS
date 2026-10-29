#include <gz/sim/System.hh>
#include <gz/plugin/Register.hh>
#include <sdf/sdf.hh>
#include <gz/sim/Model.hh>
#include <gz/sim/Link.hh>

namespace custom_drone {

class StandardPlugin : public gz::sim::System,
                       public gz::sim::ISystemConfigure,
                       public gz::sim::ISystemPreUpdate,
                       public gz::sim::ISystemPostUpdate
{
public:
  StandardPlugin() = default;
  ~StandardPlugin() override = default;

  void Configure(const gz::sim::Entity &_entity,
                 const std::shared_ptr<const sdf::Element> &_sdf,
                 gz::sim::EntityComponentManager &_ecm,
                 gz::sim::EventManager &/*_eventMgr*/) override
  {
    this->model_ = gz::sim::Model(_entity);
    if (_sdf->HasElement("motorConstant")) {
      this->motor_constant_ = _sdf->Get<double>("motorConstant");
    }
  }

  void PreUpdate(const gz::sim::UpdateInfo &_info,
                 gz::sim::EntityComponentManager &_ecm) override
  {
    if (_info.paused) return;
    // Physics manipulation hook: Add dynamic forces before solver step
  }

  void PostUpdate(const gz::sim::UpdateInfo &_info,
                  const gz::sim::EntityComponentManager &_ecm) override
  {
    if (_info.paused) return;
    // Telemetry/State reading hook: Sample world pose after physics integration
  }

private:
  gz::sim::Model model_;
  double motor_constant_{8.54e-06};
};

} // namespace custom_drone

GZ_ADD_PLUGIN(
  custom_drone::StandardPlugin,
  gz::sim::System,
  custom_drone::StandardPlugin::ISystemConfigure,
  custom_drone::StandardPlugin::ISystemPreUpdate,
  custom_drone::StandardPlugin::ISystemPostUpdate
)
