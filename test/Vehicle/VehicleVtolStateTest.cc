#include "VehicleVtolStateTest.h"

#include <QtTest/QSignalSpy>

#include "Vehicle.h"

UT_REGISTER_TEST(VehicleVtolStateTest, TestLabel::Unit, TestLabel::Vehicle)

void VehicleVtolStateTest::_transitions_data()
{
    QTest::addColumn<MAV_AUTOPILOT>("autopilot");
    QTest::newRow("PX4") << MAV_AUTOPILOT_PX4;
    QTest::newRow("ArduPilot") << MAV_AUTOPILOT_ARDUPILOTMEGA;
}

void VehicleVtolStateTest::_transitions()
{
    QFETCH(MAV_AUTOPILOT, autopilot);
    if (autopilot == MAV_AUTOPILOT_ARDUPILOTMEGA && !apmFirmwareSupported()) {
        QSKIP("ArduPilot support not registered in this build");
    }

    Vehicle vehicle(autopilot, MAV_TYPE_VTOL_TILTROTOR);
    QSignalSpy stateSpy(&vehicle, &Vehicle::vtolStateChanged);
    QSignalSpy forwardSpy(&vehicle, &Vehicle::vtolInFwdFlightChanged);
    QSignalSpy modeSpy(&vehicle, &Vehicle::flightModeChanged);
    QCOMPARE(vehicle.vtolState(), Vehicle::VtolState::Undefined);
    QCOMPARE(vehicle.vtolStateString(), QStringLiteral("VTOL state unknown"));

    const auto report = [&](uint8_t state, uint8_t component) {
        mavlink_extended_sys_state_t payload{};
        payload.vtol_state = state;
        mavlink_message_t message{};
        mavlink_msg_extended_sys_state_encode(1, component, &message, &payload);
        vehicle._handleExtendedSysState(message);
    };

    struct Step
    {
        uint8_t reported;
        Vehicle::VtolState expected;
        const char* text;
    };

    const Step steps[] = {
        {MAV_VTOL_STATE_MC, Vehicle::VtolState::MultiCopter, "Multicopter flight"},
        {MAV_VTOL_STATE_TRANSITION_TO_FW, Vehicle::VtolState::TransitionToFixedWing, "Transitioning to fixed wing"},
        {MAV_VTOL_STATE_FW, Vehicle::VtolState::FixedWing, "Fixed-wing flight"},
        {MAV_VTOL_STATE_TRANSITION_TO_MC, Vehicle::VtolState::TransitionToMultiCopter, "Transitioning to multicopter"},
        {MAV_VTOL_STATE_MC, Vehicle::VtolState::MultiCopter, "Multicopter flight"},
        // A failed front transition can return directly to MC.
        {MAV_VTOL_STATE_TRANSITION_TO_FW, Vehicle::VtolState::TransitionToFixedWing, "Transitioning to fixed wing"},
        {MAV_VTOL_STATE_MC, Vehicle::VtolState::MultiCopter, "Multicopter flight"},
        {MAV_VTOL_STATE_UNDEFINED, Vehicle::VtolState::Undefined, "VTOL state unknown"},
        {255, Vehicle::VtolState::Undefined, "VTOL state unknown"},
    };
    for (const auto& step : steps) {
        const auto previous = vehicle.vtolState();
        stateSpy.clear();
        forwardSpy.clear();
        report(step.reported, MAV_COMP_ID_CAMERA);
        QCOMPARE(vehicle.vtolState(), previous);
        QVERIFY(stateSpy.isEmpty());

        report(step.reported, vehicle.defaultComponentId());
        QCOMPARE(vehicle.vtolState(), step.expected);
        QCOMPARE(vehicle.vtolStateString(), QString::fromLatin1(step.text));
        QCOMPARE(vehicle.vtolInFwdFlight(), step.expected == Vehicle::VtolState::FixedWing);
        QCOMPARE(stateSpy.count(), previous != step.expected ? 1 : 0);
        QCOMPARE(
            forwardSpy.count(),
            (previous == Vehicle::VtolState::FixedWing) != (step.expected == Vehicle::VtolState::FixedWing) ? 1 : 0);

        stateSpy.clear();
        forwardSpy.clear();
        report(step.reported, vehicle.defaultComponentId());
        QVERIFY(stateSpy.isEmpty());
        QVERIFY(forwardSpy.isEmpty());
    }
    QVERIFY(modeSpy.isEmpty());
}

void VehicleVtolStateTest::_nonVtol()
{
    Vehicle vehicle(MAV_AUTOPILOT_PX4, MAV_TYPE_QUADROTOR);
    QSignalSpy stateSpy(&vehicle, &Vehicle::vtolStateChanged);
    mavlink_extended_sys_state_t payload{};
    payload.vtol_state = MAV_VTOL_STATE_FW;
    mavlink_message_t message{};
    mavlink_msg_extended_sys_state_encode(1, vehicle.defaultComponentId(), &message, &payload);
    vehicle._handleExtendedSysState(message);
    QCOMPARE(vehicle.vtolState(), Vehicle::VtolState::Undefined);
    QVERIFY(!vehicle.vtolInFwdFlight());
    QVERIFY(stateSpy.isEmpty());
}
