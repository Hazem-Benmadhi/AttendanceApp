// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app";
import { getAnalytics } from "firebase/analytics";
// TODO: Add SDKs for Firebase products that you want to use
// https://firebase.google.com/docs/web/setup#available-libraries

// Your web app's Firebase configuration
// For Firebase JS SDK v7.20.0 and later, measurementId is optional
const firebaseConfig = {
    apiKey: "AIzaSyBgbZvAZT0WoJgsg_A74w1P-Vr8bOQMbas",
    authDomain: "projetiot-3cf45.firebaseapp.com",
    projectId: "projetiot-3cf45",
    storageBucket: "projetiot-3cf45.firebasestorage.app",
    messagingSenderId: "592100873608",
    appId: "1:592100873608:web:9ca125794fca6505ca163d",
    measurementId: "G-FYEGMQC5VW"
};

// Initialize Firebase
export const app = initializeApp(firebaseConfig);
export const analytics = getAnalytics(app);
