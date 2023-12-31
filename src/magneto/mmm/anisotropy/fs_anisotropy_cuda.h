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

#ifndef FS_ANISOTROPY_CUDA_H
#define FS_ANISOTROPY_CUDA_H

#include "config.h"
#include "matrix/matty.h"

double fs_uniaxial_anisotropy_cuda(
	const VectorMatrix &axis,
	const       Matrix &k,
	const       Matrix &mu,
	const VectorMatrix &M,
	VectorMatrix &H,  const Matrix &Ms,bool cuda64);

double fs_cubic_anisotropy_cuda(
	const VectorMatrix &axis1,
	const VectorMatrix &axis2,
	const       Matrix &k,
	const       Matrix &mu,
	const VectorMatrix &M,
	VectorMatrix &H, const Matrix &Ms, bool cuda64
);

#endif
