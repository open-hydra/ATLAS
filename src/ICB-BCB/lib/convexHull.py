from scipy.spatial import ConvexHull

def calculate_convex_hull_volume(points):
    try:
        hull = ConvexHull(points)
        volume = hull.volume
    except Exception as e:
        volume = 0.0
    return volume

def read_datasets_from_file(file_path):
    datasets = []
    with open(file_path, 'r') as file:
        lines = file.readlines()
        i = 0
        while i < len(lines):
            points = []
            coords = [float(coord) for coord in lines[i].strip().split()]
            for t in range(int(len(coords)/3)):
                points.append(coords[0+3*t:3+3*t])
            datasets.append(points)
            i += 1
    return datasets

def main():
    file_path = "points.txt"
    out_path = "volumes.txt"
    datasets = read_datasets_from_file(file_path)
    with open(out_path, 'w') as file:
        for idx, dataset in enumerate(datasets, start=1):
            volume = calculate_convex_hull_volume(dataset)
            file.write(f"{volume}\n")

if __name__ == "__main__":
    main()
