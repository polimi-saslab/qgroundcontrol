#pragma once

#include "UnitTest.h"

class VehicleVtolStateTest : public UnitTest
{
    Q_OBJECT

private slots:
    void _transitions_data();
    void _transitions();
    void _nonVtol();
};
