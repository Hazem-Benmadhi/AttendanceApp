// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app";
import { getAnalytics } from "firebase/analytics";
// TODO: Add SDKs for Firebase products that you want to use
// https://firebase.google.com/docs/web/setup#available-libraries

const firebaseConfig = {
  apiKey: "AIzaSyBesgJxTbtYTm9m-MUZIsmeU8Ap_dsN-IA",
  authDomain: "attendance-system-f788e.firebaseapp.com",
  projectId: "attendance-system-f788e",
  storageBucket: "attendance-system-f788e.firebasestorage.app",
  messagingSenderId: "101377640608",
  appId: "1:101377640608:web:95c15788da2aca85e0a1c5"
};

// Initialize Firebase
export const app = initializeApp(firebaseConfig);
export const analytics = getAnalytics(app);
