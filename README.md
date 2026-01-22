run:

git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git
cd YOUR_REPO


Then install dependencies per project:

Angular app

cd AttendanceApp
npm install
npm start


Flutter

cd mobile
flutter pub get


AI service (Python)

cd SPAP/ai-service
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
