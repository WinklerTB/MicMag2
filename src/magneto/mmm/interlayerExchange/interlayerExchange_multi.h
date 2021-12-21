/*
 * Copyright 2012, 2013 by the Micromagnum authors.
 *
 * This file is part of MicroMagnum.
 * 
 * MicroMagnum is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * MicroMagnum is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with MicroMagnum.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef INTERLAYEREXCHANGE_MULTI_H
#define INTERLAYEREXCHANGE_MULTI_H

#include "config.h"
#include "matrix/matty.h"
#include "mesh/VectorField.h"
#include "mesh/Field.h"

double interlayerExchange_multi(
	int dim_x, int dim_y, int dim_z,
	double delta_x, double delta_y, double delta_z,
	bool periodic_x, bool periodic_y, bool periodic_z,
	const Matrix &Ms,
	const VectorMatrix &intExchPat,
	int numEntries,
	const VectorMatrix &M,
	VectorMatrix &H
);

double interlayerExchange_multi(
	const Field &Ms,
	const VectorField &intExchPat,
	const VectorField &M,
	VectorField &H
);

#endif
