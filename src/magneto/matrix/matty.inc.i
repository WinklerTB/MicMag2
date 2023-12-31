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

%{
#include <iostream>
#include "matty.h"
#include "matty_ext.h"
using namespace matty;
using namespace matty_ext;
%}

// TYPEMAPS ////////////////////////////////////////////////////////////////////////////////

%typemap(out) Vector3d
{
        $result = Py_BuildValue("(ddd)", $1.x, $1.y, $1.z);
} 

%typemap(in) (Vector3d) (double x, double y, double z, double ok)
{
        ok = PyArg_ParseTuple($input, "ddd", &x, &y, &z);
        if (!ok) {
                PyErr_SetString(PyExc_TypeError, "Expected a python 3-tuple of floats!");
                return 0;
        }
        $1 = Vector3d(x, y, z);
}

// GLOBAL FUNCTIONS ////////////////////////////////////////////////////////////////////////

void matty_initialize();
void matty_deinitialize();

// Extensions

VectorMatrix linearInterpolate(const VectorMatrix &src, Shape dest_dim);
Matrix       linearInterpolate(const       Matrix &src, Shape dest_dim);

Vector3d findExtremum(VectorMatrix &M, int z_slice, int component);

void  fftn(ComplexMatrix &inout, const std::vector<int> &loop_dims_select = std::vector<int>());
void ifftn(ComplexMatrix &inout, const std::vector<int> &loop_dims_select = std::vector<int>());

// CLASSES /////////////////////////////////////////////////////////////////////////////////

class Shape
{
public:
	Shape();
	Shape(int x0);
	Shape(int x0, int x1);
	Shape(int x0, int x1, int x2);
	Shape(int x0, int x1, int x2, int x3);
	~Shape();

	int getLinIdx(int x0) const;
	int getLinIdx(int x0, int x1) const;
	int getLinIdx(int x0, int x1, int x2) const;
	int getLinIdx(int x0, int x1, int x2, int x3) const;

	int getDim(int d) const { return dims[d]; }
	const std::vector<int> &getDims() const { return dims; }
	int getStride(int d) const { return strides[d]; }
	const std::vector<int> &getStrides() const { return strides; }

	int getRank() const { return dims.size(); }
	int getNumEl() const;

	bool sameDims(const Shape &other) const;
};

class AbstractMatrix
{
private:
        AbstractMatrix();
public:
	const Shape &getShape() const { return shape; }
	bool isUniform() const { return state == UNIFORM; }
	bool isWriteLocked() const;
	bool isLocked() const;

	/*void readLock(int dev) const;
	void readUnlock(int dev) const;
	void writeLock(int dev);
	void writeUnlock(int dev);*/
	void inspect() const; // write debug info to cout

	/*bool cache(int cache_dev) const;
	bool uncache(int uncache_dev) const;*/
	void flush() const;

	int dimX() const;
	int dimY() const;
	int dimZ() const;
	int size() const;

	void markUninitialized();
};

class Matrix : public AbstractMatrix
{
public:
	Matrix(Shape shape);
	Matrix(const Matrix &other);
	virtual ~Matrix();
	void swap(Matrix &other);

	void clear();
	void fill(double value);
	void assign(const Matrix &other);
	void scale(double factor);
	void add(const Matrix &op, double scale = 1.0);
	void multiply(const Matrix &rhs);
	void divide(const Matrix &rhs);
	void randomize();

	double maximum() const;
	double average() const;
	double sum() const;

	double getUniformValue() const;

        %extend {
                void set(int idx, double val) 
                {
                        if ($self->isUniform() && $self->getUniformValue() == val) return;

                        Matrix::rw_accessor acc(*$self);
                        acc.at(idx) = val; 
                }
                
                void set(int x, int y, int z, double val) 
                { 
                        if ($self->isUniform() && $self->getUniformValue() == val) return;

                        Matrix::rw_accessor acc(*$self);
                        acc.at(x,y,z) = val; 
                }

                double get(int idx) 
                { 
                        if ($self->isUniform()) {
                                return $self->getUniformValue();
                        } else {
                                Matrix::ro_accessor acc(*$self);
                                return acc.at(idx);
                        }
                }

                double get(int x, int y, int z) 
                { 
                        if ($self->isUniform()) {
                                return $self->getUniformValue();
                        } else {
                                Matrix::ro_accessor acc(*$self);
                                return acc.at(x,y,z);
                        }
                }

                PythonByteArray toByteArray()
                {
                        PythonByteArray arr($self->size() * sizeof(double));
                        double *arr_ptr = (double*)arr.get();
                
                        Matrix::ro_accessor acc(*$self);
                        for (int i=0; i<$self->size(); ++i) 
                        {
                                *arr_ptr++ = acc.at(i);
                        }
                
                        return arr;
                }
                //inspired by https://stackoverflow.com/questions/51427455/input-python-3-bytes-to-c-char-via-swig
                %typemap(in) (const char * arr) {
                        Py_ssize_t l;
                        PyBytes_AsStringAndSize($input, &$1, &l);
                }
                void fromByteArray(const char* arr)
                {
                        
                        Matrix::rw_accessor acc(*$self);
                        const double *arr_ptr = (const double*)arr;
                        double *acc_ptr = acc.ptr();
                        memcpy(acc_ptr, arr_ptr, $self->size() * sizeof(double));
//                        for (int i=0; i<$self->size(); ++i) 
//                        {
//                                double value = *arr_ptr++;
//                                std::cout << i << "\t" << value << std::endl;
//                                acc.at(i) = value;
//                                *acc_ptr++ = value;
//                        }

                }
        } /* %extend */
};

class VectorMatrix : public AbstractMatrix
{
        %rename(scale_by_vector) scale(Vector3d factors);

public:
	VectorMatrix(const Shape &shape);
	VectorMatrix(const VectorMatrix &other);
	virtual ~VectorMatrix();
	void swap(VectorMatrix &other);

	void clear();
	void fill(Vector3d value);
	void assign(const VectorMatrix &other);
	void scale(double factor);
	void scale(Vector3d factors);
	void multiplyField(class Matrix &op);
	void add(const VectorMatrix &op, double scale = 1.0);
	void randomize();

	void normalize(double len);
	void normalize(const class Matrix &len);

	double absMax() const;
	double dotSum(const VectorMatrix &other) const;

	//Vector3d mininum() const;
	Vector3d maximum() const;
	Vector3d average() const;
	Vector3d sum() const;

	Vector3d getUniformValue() const;

        %extend {
                void set(int idx, Vector3d val) 
                {
                        if ($self->isUniform() && $self->getUniformValue() == val) return;

                        VectorMatrix::accessor acc(*$self);
                        acc.set(idx, val); 
                }
                
                void set(int x, int y, int z, Vector3d val) 
                { 
                        if ($self->isUniform() && $self->getUniformValue() == val) return;

                        VectorMatrix::accessor acc(*$self);
                        acc.set(x,y,z, val); 
                }

                Vector3d get(int idx) 
                { 
                        if ($self->isUniform()) {
                                return $self->getUniformValue();
                        } else {
                                VectorMatrix::const_accessor acc(*$self);
                                return acc.get(idx);
                        }
                }

                Vector3d get(int x, int y, int z) 
                { 
                        if ($self->isUniform()) {
                                return $self->getUniformValue();
                        } else {
                                VectorMatrix::const_accessor acc(*$self);
                                return acc.get(x,y,z);
                        }
                }

                PythonByteArray toByteArray()
                {
                        PythonByteArray arr($self->size() * 3 * sizeof(double));
                        double *arr_ptr = (double*)arr.get();
                
                        VectorMatrix::const_accessor acc(*$self);
                        for (int i=0; i<$self->size(); ++i) 
                        {
                                const Vector3d vec = acc.get(i);
                                *arr_ptr++ = vec.x;
                                *arr_ptr++ = vec.y;
                                *arr_ptr++ = vec.z;
                        }
                
                        return arr;
                }
                
                PythonByteArray toByteArray(int component)
                {
                        PythonByteArray arr($self->size() * sizeof(double));
                        double *arr_ptr = (double*)arr.get();
                
                        VectorMatrix::const_accessor acc(*$self);
                        for (int i=0; i<$self->size(); ++i) 
                        {
                                *arr_ptr++ = acc.get(i)[component];
                        }
                
                        return arr;
                }

                //inspired by https://stackoverflow.com/questions/51427455/input-python-3-bytes-to-c-char-via-swig
                %typemap(in) (const char * arr) {
                        Py_ssize_t l;
                        PyBytes_AsStringAndSize($input, &$1, &l);
                }
                void fromByteArray(const char* arr)
                {
                        VectorMatrix::accessor acc(*$self);
                        const double *arr_ptr = (const double*)arr;
                        for (int i=0; i<$self->size(); ++i) 
                        {
                                double mx = *arr_ptr++;
                                double my = *arr_ptr++;
                                double mz = *arr_ptr++;
                                Vector3d vec(mx,my,mz);
                                acc.set(i,vec);
                        }
                }
        } /* %extend */
};

class ComplexMatrix : public AbstractMatrix
{
public:
	ComplexMatrix(const Shape &shape);
	ComplexMatrix(const ComplexMatrix &other);
	virtual ~ComplexMatrix();

	void clear();
	void fill(double real, double imag);
	void fill(std::complex<double> value);
	void assign(const ComplexMatrix &other);

	std::complex<double> getUniformValue() const;
};

// INIT CODE ////////////////////////////////////////////////////////////////////////////

%pythoncode %{

def extend():

  def get_shape(self):
    sh = self.getShape()
    return (sh.getDim(0), sh.getDim(1), sh.getDim(2))
    
  def get_rank(self):
    sh = self.getShape()
    return sh.getRank()
    
  def get_uniform_value(self):
    if not self.isUniform():
      raise ValueError("VectorMatrix must be uniform in order to access the uniform_value property!")
    return self.getUniformValue()
    
  def the_repr(self):
     return  "VectorMatrix(%r)" % (self.shape,)
  
  AbstractMatrix.shape         = property(get_shape)
  AbstractMatrix.rank          = property(get_rank)
  AbstractMatrix.uniform_value = property(get_uniform_value)

  VectorMatrix.element_size    = property(lambda self: 3)
  VectorMatrix.__repr__        = lambda self: "VectorMatrix(%r)" % (self.shape,)

  Matrix.element_size          = property(lambda self: 1)
  Matrix.__repr__              = lambda self: "Matrix(%r)" % (self.shape,)

  ComplexMatrix.__repr__       = lambda self: "ComplexMatrix(%r)" % (self.shape,)
  ComplexMatrix.element_size   = property(lambda self: 3)

  def vector_matrix_to_numpy(self):
    # Get raw data
    data = self.toByteArray()
  
    # Convert to numpy array
    try:
      import numpy as np
    except ImportError:
      raise ImportError("numpy library not found!")
    N = np.frombuffer(data, dtype=np.float64, count=3*self.size())
    N.shape = self.shape + (3,)
    N.strides = (N.itemsize * 3, N.itemsize * 3 * self.dimX(), N.itemsize * 3 * self.dimX() * self.dimY(), N.itemsize)
    return N

  def vector_matrix_from_numpy(self, N):
    try:
      import numpy as np
    except ImportError:
      raise ImportError("numpy library not found!")
    # error handling - test for shape and data type
    if(N.ndim != 4):
      raise ValueError("VectorField.from_numpy(N): N.ndim must be 4")
    if(N.shape[3] != 3):
      raise ValueError("VectorField.from_numpy(N): N.shape[3] must be 3")
    if(N.shape[:3] != self.shape):
      raise ValueError("VectorField.from_numpy(N): N.shape[:3] must be the same as the VectorField's dimension")
    try:
      N = N.astype(float)
    except:
      raise ValueError('VectorField.from_numpy(N): N must be convertable to float')
    self.fromByteArray(np.swapaxes(N,2,0).flatten().tobytes(order='C'))

  VectorMatrix.to_numpy   = vector_matrix_to_numpy
  VectorMatrix.from_numpy = vector_matrix_from_numpy

  def matrix_to_numpy(self):
    # Get raw data
    data = self.toByteArray()
  
    # Convert to numpy array
    try:
      import numpy as np
    except ImportError:
      raise ImportError("numpy library not found!")
    N = np.frombuffer(data, dtype=np.float64, count=self.size())
    N.shape = self.shape
    N.strides = (N.itemsize, N.itemsize * self.dimX(), N.itemsize * self.dimX() * self.dimY())
    return N

  def matrix_from_numpy(self, N):
    try:
      import numpy as np
    except ImportError:
      raise ImportError("numpy library not found!")
    # error handling - test for shape and data type
    if(N.shape != self.shape):
      raise ValueError("Field.from_numpy(N): N.shape must be the same as the Field's dimension")
    try:
      N = N.astype(float)
    except:
      raise ValueError("Field.from_numpy(N): N must be convertable to float")
    self.fromByteArray(np.swapaxes(N,2,0).flatten().tobytes(order='C'))

  Matrix.to_numpy   = matrix_to_numpy
  Matrix.from_numpy = matrix_from_numpy

extend()
del extend

matty_initialize()

%}

