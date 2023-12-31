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

#include "config.h"
#include "fs_exchange_cpu.h"
#include "mmm/constants.h"
#include <iostream>


static double fs_exchange_cpu_nonperiodic(
	int dim_x, int dim_y, int dim_z,
	double delta_x, double delta_y, double delta_z,
	const Matrix &mu,
	const Matrix &J,
	const VectorMatrix &M,
	VectorMatrix &H
);

static double fs_exchange_cpu_periodic(
	int dim_x, int dim_y, int dim_z,
	double delta_x, double delta_y, double delta_z,
	bool periodic_x, bool periodic_y, bool periodic_z,
	const Matrix &mu,
	const Matrix &J,
	const VectorMatrix &M,
	VectorMatrix &H
);

double fs_exchange_cpu(
	int dim_x, int dim_y, int dim_z,
	double delta_x, double delta_y, double delta_z,
	bool periodic_x, bool periodic_y, bool periodic_z,
	const Matrix &mu,
	const Matrix &J,
	const VectorMatrix &M,
	VectorMatrix &H)
{
	const bool periodic = periodic_x || periodic_y || periodic_z;
	if (periodic) {
		return fs_exchange_cpu_periodic(dim_x, dim_y, dim_z, delta_x, delta_y, delta_z, periodic_x, periodic_y, periodic_z, mu, J, M, H);
	} else {
		return fs_exchange_cpu_nonperiodic(dim_x, dim_y, dim_z, delta_x, delta_y, delta_z, mu, J, M, H);
	}
}

static double fs_exchange_cpu_nonperiodic(
	int dim_x, int dim_y, int dim_z,
	double delta_x, double delta_y, double delta_z,
	const Matrix &mu,
	const Matrix &J,
	const VectorMatrix &M,
	VectorMatrix &H)
{
		VectorMatrix::const_accessor M_acc(M);
		VectorMatrix::accessor H_acc(H);
		Matrix::ro_accessor spin_acc(mu), J_acc(J);
        //std::cout << "Sono in excange_cpu" << std::endl;
        int dim_xy= dim_x*dim_y;
		double energy = 0.0;
	for (int z=0; z<dim_z; ++z) {
		for (int y=0; y<dim_y; ++y) {	
			for (int x=0; x<dim_x; ++x) {
				const int i = z*dim_xy + y*dim_x + x; // linear index of (x,y,z)
				const double spin = spin_acc.at(i);
				const Vector3d M_i = M_acc.get(i);
				if (spin == 0.0) {
					H_acc.set(i, Vector3d(0.0, 0.0, 0.0));
					continue;
				}

				const int idx_l = i-     1;
				const int idx_r = i+     1;
				const int idx_u = i- dim_x;
				const int idx_d = i+ dim_x;
				const int idx_f = i-dim_xy;
				const int idx_b = i+dim_xy;

				Vector3d sum(0.0, 0.0, 0.0);
				
				// left / right (X)
				if (x >       0) {
					const double spin_l = spin_acc.at(idx_l);
					if (spin_l != 0.0) sum += M_acc.get(idx_l)/spin_l;
				}
				if (x < dim_x-1) {
					const double spin_r = spin_acc.at(idx_r);	
					if (spin_r != 0.0) sum += M_acc.get(idx_r)/spin_r;
				}
				// up / down (Y)
				if (y >       0) {
					const double spin_u = spin_acc.at(idx_u);
					if (spin_u != 0.0) sum += M_acc.get(idx_u)/spin_u;
				}
				if (y < dim_y-1) {
					const double spin_d = spin_acc.at(idx_d);
					if (spin_d != 0.0) sum += M_acc.get(idx_d)/spin_d;
				}
				// forward / backward (Z)
				if (z >       0) {
					const double spin_f = spin_acc.at(idx_f);
					if (spin_f != 0.0) sum += M_acc.get(idx_f)/spin_f;
				}
				if (z < dim_z-1) {
					const double spin_b = spin_acc.at(idx_b);
					if (spin_b != 0.0) sum += M_acc.get(idx_b)/spin_b;
				}

				// Exchange field at (x,y,z)
				Vector3d H_i = J_acc.at(i) * (sum)/(spin*MU0);				
				H_acc.set(i, H_i);
				//std::cout << x << y << H_i << std::endl;
				// Exchange energy sum
				energy += dot(M_i, H_i);
				
			}
		}
	}
return energy;

}


static double fs_exchange_cpu_periodic(
	int dim_x, int dim_y, int dim_z,
	double delta_x, double delta_y, double delta_z,
	bool periodic_x, bool periodic_y, bool periodic_z,
	const Matrix &mu,
	const Matrix &J,
	const VectorMatrix &M,
	VectorMatrix &H)
{
	const int dim_xy = dim_x * dim_y;

	VectorMatrix::const_accessor M_acc(M);
	VectorMatrix::accessor H_acc(H);
	Matrix::ro_accessor J_acc(J), spin_acc(mu);

	double energy = 0.0;
	for (int z=0; z<dim_z; ++z) {
		for (int y=0; y<dim_y; ++y) {	
			for (int x=0; x<dim_x; ++x) {
				const int i = z*dim_xy + y*dim_x + x; // linear index of (x,y,z)
				const double spin = spin_acc.at(i);
				if (spin == 0.0) {
					H_acc.set(i, Vector3d(0.0, 0.0, 0.0));
					continue;
				}

				int idx_l = i -      1;
				int idx_r = i +      1;
				int idx_u = i -  dim_x;
				int idx_d = i +  dim_x;
				int idx_f = i - dim_xy;
				int idx_b = i + dim_xy;

				// wrap-around for periodic boundary conditions
				if (periodic_x) {
					if (x ==       0) idx_l += dim_x;
					if (x == dim_x-1) idx_r -= dim_x;
				}
				if (periodic_y) {
					if (y ==       0) idx_u += dim_xy;
					if (y == dim_y-1) idx_d -= dim_xy;
				}
				if (periodic_z) {
					if (z ==       0) idx_f += dim_xy*dim_z;
					if (z == dim_z-1) idx_b -= dim_xy*dim_z;
				}

				const Vector3d M_i = M_acc.get(i); 

				Vector3d sum(0.0, 0.0, 0.0);

				// left / right (X)
				if (x >       0 || periodic_x) {
					const double spin_l = spin_acc.at(idx_l);
					if (spin_l != 0.0) sum += (M_acc.get(idx_l) / spin_l);
				}
				if (x < dim_x-1 || periodic_x) {
					const double spin_r = spin_acc.at(idx_r);	
					if (spin_r != 0.0) sum += (M_acc.get(idx_r) / spin_r);
				}
				// up / down (Y)
				if (y >       0 || periodic_y) {
					const double spin_u = spin_acc.at(idx_u);
					if (spin_u != 0.0) sum += (M_acc.get(idx_u) / spin_u);
				}
				if (y < dim_y-1 || periodic_y) {
					const double spin_d = spin_acc.at(idx_d);
					if (spin_d != 0.0) sum += (M_acc.get(idx_d) / spin_d);
				}
				// forward / backward (Z)
				if (z >       0 || periodic_z) {
					const double spin_f = spin_acc.at(idx_f);
					if (spin_f != 0.0) sum += (M_acc.get(idx_f) / spin_f);
				}
				if (z < dim_z-1 || periodic_z) {
					const double spin_b = spin_acc.at(idx_b);
					if (spin_b != 0.0) sum += (M_acc.get(idx_b) / spin_b);
				}

				// Exchange field at (x,y,z)
				const Vector3d H_i = J_acc.at(i)*sum/(spin*MU0);//(2/MU0) * A_acc.at(i) * sum / Ms;
				H_acc.set(i, H_i);

				// Exchange energy sum
				energy += dot(M_i, H_i);
			}
		}
	}
	return energy;
}
