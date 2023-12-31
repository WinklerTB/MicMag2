# Copyright 2012, 2013 by the Micromagnum authors.
#
# This file is part of MicroMagnum.
#
# MicroMagnum is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# MicroMagnum is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with MicroMagnum.  If not, see <http://www.gnu.org/licenses/>.

import magnum.module as module
import magnum.magneto as magneto
from magnum.mesh import VectorField, Field
from .constants import MU0

class ExchangeFieldNNN(module.Module):
    def __init__(self):
        super(ExchangeFieldNNN, self).__init__()

    def calculates(self):
        return ["H_exch_nnn", "E_exch_nnn"]

    def params(self):
        return ["A"]

    def properties(self):
        return {'EFFECTIVE_FIELD_TERM': "H_exch_nnn", 'EFFECTIVE_FIELD_ENERGY': "E_exch_nnn"}

    def initialize(self, system):
        self.system = system
        self.A = Field(self.system.mesh); self.A.fill(0.0)
        self.__peri_x = system.mesh.periodic_bc[0].find("x") != -1
        self.__peri_y = system.mesh.periodic_bc[0].find("y") != -1
        self.__peri_z = system.mesh.periodic_bc[0].find("z") != -1

    def calculate(self, state, id):
        #print "test_exch", state.M.average()
        cache = state.cache

        if id == "H_exch_nnn":
            if hasattr(cache, "H_exch_nnn"): return cache.H_exch_nnn
            H_exch_nnn = cache.H_exch_nnn = VectorField(self.system.mesh)

            #nx, ny, nz = self.system.mesh.num_nodes
            #dx, dy, dz = self.system.mesh.delta
            #bcx, bcy, bcz = self.__peri_x, self.__peri_y, self.__peri_z
            magneto.exchange_nnn(state.Ms, self.system.A, state.M, H_exch_nnn,1,1,1)
            return H_exch_nnn

        elif id == "E_exch_nnn":
            #print("Exchange MM: ", -MU0/2.0 * self.system.mesh.cell_volume * state.M.dotSum(state.H_exch) )
            return -MU0/2.0 * self.system.mesh.cell_volume * state.M.dotSum(state.H_exch_nnn)

        else:
            raise KeyError("ExchangeFieldNNN.calculate: Can't calculate %s", id)
