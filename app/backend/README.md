# reach the backend directory 
cd backend

# create your own virtual environment
python -m venv venv

# activate it 
.\venv\Scripts\Activate

# install dependencies
pip install -r requirements.txt

# set up env variables
all required keys 

# run the backend 
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload