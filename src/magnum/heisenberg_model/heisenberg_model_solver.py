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

from __future__ import print_function

import magnum.tools as tools
import magnum.solver as solver
import magnum.evolver as evolver

from .heisenberg_model import HeisenbergModel
from .io import writeOMF

class HeisenbergModelSolver(solver.Solver):
    def __init__(self, system, evolver, world):
        super(HeisenbergModelSolver, self).__init__(system, evolver)
        self.__world = world
        self.system = system

    def __repr__(self):
        return "HeisenbergModelSolver@%s" % hex(id(self))

    world = property(lambda self: self.__world)

    def relax(self, *args, **kwargs):
        # catch CVode, when using relax condition
        if self.evolver.__class__.__name__ == "Cvode":
          raise Exception("CVode is not usable to relax a system, yet. Please use rkf45.")

        return self.solve(solver.condition.Relaxed(*args, **kwargs))

    def handle_interrupt(self):
        print()

        text = ""
        text += "State:\n"
        text += "       step = %s\n" % self.state.step
        text += "          t = %s\n" % self.state.t
        text += "     avg(M) = %s\n" % (self.state.M.average(),)
        text += " deg_per_ns = %s\n" % self.state.deg_per_ns
        text += "\n"
        text += "Mesh: %s\n" % self.mesh
        text += "\n"
        text += "Options:"

        from .stephandler import ScreenLog
        loggers = [h for (h, _) in self.step_handlers if isinstance(h, ScreenLog)]

        answer = tools.interactive_menu(
          header = "Solver interrupted by signal SIGINT (ctrl-c)",
          text = text,
          options = [
            "Continue",
            "Stop solver and return the current state as the result",
            "Save current magnetization to .omf file, then continue",
            "Raise KeyboardInterrupt",
            "Kill program",
            "Start debugger",
            "Toggle console log (now:%s)" % ("enabled" if loggers else "disabled")
          ]
        )
        if answer == 1:
            return
        elif answer == 2:
            raise solver.Solver.FinishSolving()
        elif answer == 3:
            print("Enter file name ('.omf' is appended automatically)")
            path = tools.getline() + ".omf"
            writeOMF(path, self.state.M)
            print("Done.")
            return False
        elif answer == 4:
            raise KeyboardInterrupt()
        elif answer == 5:
            import sys
            sys.exit(-1)
        elif answer == 6:
            raise solver.Solver.StartDebugger()
        elif answer == 7:
            if loggers:
                for logger in loggers: self.removeStepHandler(logger)
                print("Disabled console log.")
            else:
                from magnum.solver.condition import EveryNthStep
                self.addStepHandler(ScreenLog(), EveryNthStep(100))
                print("Enabled console log.")
            return
        assert False
