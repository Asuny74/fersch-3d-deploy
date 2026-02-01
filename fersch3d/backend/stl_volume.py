"""
Utility functions to parse STL files and compute their volume.

This module supports both ASCII and binary STL formats. It reads the
contents of an STL file, extracts triangle facets and computes the
enclosed volume using the divergence theorem. Volumes are returned in
millilitres (ml) assuming the STL units are millimetres.

The volume computation algorithm is adapted from standard formulas
where each triangular facet contributes a signed volume given by:

    V = (1.0/6.0) * dot(v1, cross(v2, v3))

for vertices v1, v2 and v3 measured relative to the origin. Summing
the signed volumes of all facets yields the total volume, which is
converted from cubic millimetres to millilitres (1 ml = 1,000 mm³).

If the STL file is ASCII, the parser looks for lines starting with
"vertex". For binary STL files, the parser reads the header, the
number of triangles and then unpacks each facet.

Author: Fersch 3D quoting engine
"""

from __future__ import annotations

import struct
from pathlib import Path
from typing import Iterable, Tuple


def parse_ascii_vertices(lines: Iterable[str]) -> Iterable[Tuple[float, float, float]]:
    """Yield vertex coordinates from an ASCII STL iterator.

    Each "vertex" line is expected to contain three floating point
    coordinates separated by whitespace. Other lines are ignored.

    Args:
        lines: An iterable of strings representing the file contents.

    Yields:
        Tuples of (x, y, z) floats for each vertex.
    """
    for line in lines:
        line = line.strip()
        if line.lower().startswith("vertex"):
            parts = line.split()
            # vertex lines typically look like: vertex x y z
            try:
                x, y, z = float(parts[1]), float(parts[2]), float(parts[3])
                yield (x, y, z)
            except (IndexError, ValueError):
                # Skip malformed vertex lines
                continue


def parse_binary_facets(data: bytes) -> Iterable[Tuple[Tuple[float, float, float], Tuple[float, float, float], Tuple[float, float, float]]]:
    """Yield triangular facets from a binary STL payload.

    Binary STL format:
        - 80 byte header
        - 4 byte unsigned int: number of triangles
        - For each triangle:
            - 12 byte normal vector (ignored here)
            - 12 byte vertex 1
            - 12 byte vertex 2
            - 12 byte vertex 3
            - 2 byte attribute byte count (ignored)

    Args:
        data: The binary STL payload starting after the triangle count.

    Yields:
        Triples of vertex coordinates (v1, v2, v3).
    """
    facet_size = 50  # bytes per facet (12 normal + 3*12 vertices + 2 attr)
    for i in range(0, len(data), facet_size):
        chunk = data[i : i + facet_size]
        if len(chunk) < facet_size:
            break
        # Skip normal vector (first 12 bytes)
        v1 = struct.unpack("<3f", chunk[12:24])
        v2 = struct.unpack("<3f", chunk[24:36])
        v3 = struct.unpack("<3f", chunk[36:48])
        yield (v1, v2, v3)


def signed_tetrahedron_volume(v1: Tuple[float, float, float], v2: Tuple[float, float, float], v3: Tuple[float, float, float]) -> float:
    """Compute the signed volume of the tetrahedron formed by three vertices and the origin.

    Args:
        v1, v2, v3: The vertices of the triangle.

    Returns:
        The signed volume contribution in cubic millimetres.
    """
    # Compute cross product v2 x v3
    cx = v2[1] * v3[2] - v2[2] * v3[1]
    cy = v2[2] * v3[0] - v2[0] * v3[2]
    cz = v2[0] * v3[1] - v2[1] * v3[0]
    # Dot product v1 . (v2 x v3)
    dot = v1[0] * cx + v1[1] * cy + v1[2] * cz
    return dot / 6.0


def compute_volume_ml(file_path: str | Path) -> float:
    """Compute the volume of an STL file in millilitres.

    This function delegates to :func:`compute_volume_and_bbox` and returns
    only the volume component. It is kept for backward compatibility.
    """
    volume_ml, _ = compute_volume_and_bbox(file_path)
    return volume_ml


def compute_volume_and_bbox(file_path: str | Path) -> Tuple[float, Tuple[float, float, float]]:
    """Compute the volume (ml) and bounding box dimensions (mm) of an STL file.

    Args:
        file_path: Path to the STL file.

    Returns:
        A tuple ``(volume_ml, (length_mm, width_mm, height_mm))`` where
        ``length_mm`` ≥ ``width_mm`` ≥ ``height_mm`` correspond to the
        extents of the model along the x, y and z axes respectively.
    """
    path = Path(file_path)
    data = path.read_bytes()
    is_ascii = data[:5].lower() == b"solid" and b"facet" in data[:200]
    total_volume_mm3 = 0.0
    # Initialize bounding box
    min_x = min_y = min_z = float("inf")
    max_x = max_y = max_z = float("-inf")
    if is_ascii:
        lines = data.decode("utf-8", errors="ignore").splitlines()
        vertices = []
        for v in parse_ascii_vertices(lines):
            # Update bounds
            x, y, z = v
            min_x = min(min_x, x)
            min_y = min(min_y, y)
            min_z = min(min_z, z)
            max_x = max(max_x, x)
            max_y = max(max_y, y)
            max_z = max(max_z, z)
            vertices.append(v)
            if len(vertices) == 3:
                v1, v2, v3 = vertices
                total_volume_mm3 += signed_tetrahedron_volume(v1, v2, v3)
                vertices = []
    else:
        if len(data) < 84:
            return 0.0, (0.0, 0.0, 0.0)
        num_triangles = struct.unpack("<I", data[80:84])[0]
        facets_data = data[84:]
        count = 0
        for v1, v2, v3 in parse_binary_facets(facets_data):
            # Update bounds for each vertex
            for v in (v1, v2, v3):
                x, y, z = v
                min_x = min(min_x, x)
                min_y = min(min_y, y)
                min_z = min(min_z, z)
                max_x = max(max_x, x)
                max_y = max(max_y, y)
                max_z = max(max_z, z)
            total_volume_mm3 += signed_tetrahedron_volume(v1, v2, v3)
            count += 1
            if count >= num_triangles:
                break
    volume_ml = abs(total_volume_mm3) / 1000.0
    # Compute dimensions
    length = max_x - min_x if max_x > min_x else 0.0
    width = max_y - min_y if max_y > min_y else 0.0
    height = max_z - min_z if max_z > min_z else 0.0
    # Sort dimensions descending (length ≥ width ≥ height)
    dims = sorted([length, width, height], reverse=True)
    return volume_ml, (dims[0], dims[1], dims[2])
