"""
Test script to compare two face images and check if they belong to the same person.
This tests the face recognition system's ability to identify and match faces.
"""

import os
import sys
import base64
from pathlib import Path

# Add parent directory to path to import app modules
sys.path.insert(0, str(Path(__file__).parent))

from app.face_recognition import FaceRecognizer
from app.config import settings
from PIL import Image
from deepface import DeepFace
import numpy as np


def load_image_as_base64(image_path: str) -> str:
    """Load an image file and convert it to base64 string."""
    with open(image_path, 'rb') as image_file:
        encoded_string = base64.b64encode(image_file.read()).decode('utf-8')
        return f"data:image/jpeg;base64,{encoded_string}"


def get_image_info(image_array: np.ndarray) -> dict:
    """Get diagnostic information about an image."""
    return {
        'shape': image_array.shape,
        'dtype': str(image_array.dtype),
        'min': int(image_array.min()),
        'max': int(image_array.max()),
        'mean': float(image_array.mean())
    }


def try_extract_embedding_flexible(image_array: np.ndarray, image_name: str) -> tuple:
    """Try to extract embedding with multiple strategies."""
    
    # Strategy 1: Try with strict detection (opencv)
    print(f"  → Attempting with opencv detector (strict)...")
    try:
        embedding_objs = DeepFace.represent(
            img_path=image_array,
            model_name=settings.MODEL_NAME,
            enforce_detection=True,
            detector_backend='opencv'
        )
        if embedding_objs and len(embedding_objs) > 0:
            print(f"  ✓ Success with opencv detector")
            return embedding_objs[0]["embedding"], 'opencv (strict)'
    except Exception as e:
        print(f"  ✗ opencv (strict) failed: {str(e)[:60]}...")
    
    # Strategy 2: Try with retinaface (more accurate)
    print(f"  → Attempting with retinaface detector...")
    try:
        embedding_objs = DeepFace.represent(
            img_path=image_array,
            model_name=settings.MODEL_NAME,
            enforce_detection=True,
            detector_backend='retinaface'
        )
        if embedding_objs and len(embedding_objs) > 0:
            print(f"  ✓ Success with retinaface detector")
            return embedding_objs[0]["embedding"], 'retinaface'
    except Exception as e:
        print(f"  ✗ retinaface failed: {str(e)[:60]}...")
    
    # Strategy 3: Try without strict detection
    print(f"  → Attempting with relaxed detection...")
    try:
        embedding_objs = DeepFace.represent(
            img_path=image_array,
            model_name=settings.MODEL_NAME,
            enforce_detection=False,
            detector_backend='opencv'
        )
        if embedding_objs and len(embedding_objs) > 0:
            print(f"  ⚠ Success with relaxed detection (less reliable)")
            return embedding_objs[0]["embedding"], 'opencv (relaxed)'
    except Exception as e:
        print(f"  ✗ relaxed detection failed: {str(e)[:60]}...")
    
    return None, None


def compare_two_images(image1_path: str, image2_path: str):
    """
    Compare two images and determine if they show the same person.
    
    Args:
        image1_path: Path to the first image
        image2_path: Path to the second image
    """
    print("=" * 80)
    print("Face Recognition Test - Comparing Two Images")
    print("=" * 80)
    print(f"\nImage 1: {image1_path}")
    print(f"Image 2: {image2_path}")
    print(f"\nModel: {settings.MODEL_NAME}")
    print(f"Distance Metric: {settings.DISTANCE_METRIC}")
    print(f"Recognition Threshold: {settings.RECOGNITION_THRESHOLD}")
    print("\n" + "-" * 80)
    
    # Initialize face recognizer
    print("\n[1/4] Initializing Face Recognizer...")
    recognizer = FaceRecognizer()
    
    # Load images
    print("[2/4] Loading images...")
    try:
        image1_base64 = load_image_as_base64(image1_path)
        image2_base64 = load_image_as_base64(image2_path)
        print("✓ Images loaded successfully")
    except Exception as e:
        print(f"✗ Error loading images: {e}")
        return
    
    # Extract embeddings
    print("\n[3/4] Extracting face embeddings...")
    
    print("\n  Image 1 Analysis:")
    print("  → Loading and analyzing image...")
    image1_array = recognizer._base64_to_image(image1_base64)
    info1 = get_image_info(image1_array)
    print(f"    • Shape: {info1['shape']} (Height x Width x Channels)")
    print(f"    • Pixel range: {info1['min']}-{info1['max']}, Mean: {info1['mean']:.1f}")
    
    print("  → Extracting face embedding with multiple strategies...")
    embedding1, method1 = try_extract_embedding_flexible(image1_array, "Image 1")
    
    if embedding1 is None:
        print("\n  ✗ FAILED: Could not detect face in Image 1 with any method")
        print("\n  Troubleshooting tips:")
        print("    • Ensure the image clearly shows a face")
        print("    • Face should be front-facing (not profile)")
        print("    • Image should have good lighting")
        print("    • Face should not be too small or too large")
        print("    • Try a different image or crop the face more closely")
        return
    print(f"  ✓ Face detected in Image 1 (embedding dimension: {len(embedding1)}, method: {method1})")
    
    print("\n  Image 2 Analysis:")
    print("  → Loading and analyzing image...")
    image2_array = recognizer._base64_to_image(image2_base64)
    info2 = get_image_info(image2_array)
    print(f"    • Shape: {info2['shape']} (Height x Width x Channels)")
    print(f"    • Pixel range: {info2['min']}-{info2['max']}, Mean: {info2['mean']:.1f}")
    
    print("  → Extracting face embedding with multiple strategies...")
    embedding2, method2 = try_extract_embedding_flexible(image2_array, "Image 2")
    
    if embedding2 is None:
        print("\n  ✗ FAILED: Could not detect face in Image 2 with any method")
        print("\n  Troubleshooting tips:")
        print("    • Ensure the image clearly shows a face")
        print("    • Face should be front-facing (not profile)")
        print("    • Image should have good lighting")
        print("    • Face should not be too small or too large")
        print("    • Try a different image or crop the face more closely")
        return
    print(f"  ✓ Face detected in Image 2 (embedding dimension: {len(embedding2)}, method: {method2})")
    
    # Compare embeddings
    print("\n[4/4] Comparing faces...")
    distance = recognizer.compute_cosine_distance(embedding1, embedding2)
    similarity_percentage = (1 - distance) * 100
    
    print("\n" + "=" * 80)
    print("RESULTS")
    print("=" * 80)
    print(f"\nCosine Distance: {distance:.4f}")
    print(f"Similarity Score: {similarity_percentage:.2f}%")
    print(f"Recognition Threshold: {settings.RECOGNITION_THRESHOLD:.4f}")
    
    if distance < settings.RECOGNITION_THRESHOLD:
        print("\n✓ MATCH: The two images show the SAME person")
        confidence = (1 - (distance / settings.RECOGNITION_THRESHOLD)) * 100
        print(f"  Confidence: {confidence:.2f}%")
    else:
        print("\n✗ NO MATCH: The two images show DIFFERENT people")
        difference = ((distance - settings.RECOGNITION_THRESHOLD) / settings.RECOGNITION_THRESHOLD) * 100
        print(f"  Difference: {difference:.2f}% above threshold")
    
    print("\n" + "=" * 80)
    
    return {
        'distance': distance,
        'similarity': similarity_percentage,
        'match': distance < settings.RECOGNITION_THRESHOLD,
        'threshold': settings.RECOGNITION_THRESHOLD
    }


def main():
    """Main function to run the face comparison test."""
    
    # Check if images are provided as arguments
    if len(sys.argv) >= 3:
        image1_path = sys.argv[1]
        image2_path = sys.argv[2]
    else:
        # Use default test images (you'll need to place them in temp_images folder)
        print("Usage: python test_face_comparison.py <image1_path> <image2_path>")
        print("\nExample:")
        print("  python test_face_comparison.py temp_images/person1.jpg temp_images/person2.jpg")
        
        # Try to use images from temp_images if they exist
        test_image_dir = Path(__file__).parent / "temp_images"
        available_images = list(test_image_dir.glob("*.jpg")) + list(test_image_dir.glob("*.png"))
        
        if len(available_images) >= 2:
            print(f"\nFound {len(available_images)} images in temp_images folder.")
            print("Using first two images for testing...")
            image1_path = str(available_images[0])
            image2_path = str(available_images[1])
        else:
            print("\n✗ Error: Please provide two image paths as arguments")
            return
    
    # Verify files exist
    if not os.path.exists(image1_path):
        print(f"✗ Error: Image 1 not found: {image1_path}")
        return
    
    if not os.path.exists(image2_path):
        print(f"✗ Error: Image 2 not found: {image2_path}")
        return
    
    # Run comparison
    try:
        compare_two_images(image1_path, image2_path)
    except Exception as e:
        print(f"\n✗ Error during comparison: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()
