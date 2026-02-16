from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from datetime import timedelta
from .database import get_db
from . import models, schemas, auth
from .config import settings
from .routers import structures, users, norms, grades, steps, maintenance

app = FastAPI(title="Personal Health Consultant API")

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins(),
    allow_origin_regex=settings.CORS_ORIGIN_REGEX,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(structures.router, tags=["structures"])
app.include_router(users.router, tags=["users"])
app.include_router(norms.router, tags=["norms"])
app.include_router(grades.router, tags=["grades"])
app.include_router(steps.router, tags=["steps"])
app.include_router(maintenance.router, tags=["maintenance"])

@app.post("/token")
async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.login == form_data.username).first()
    if not user or not auth.verify_password(form_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=auth.settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = auth.create_access_token(
        data={"sub": user.login, "role": user.role.value}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer", "role": user.role.value, "id": user.id, "full_name": user.full_name}

@app.get("/")
def read_root():
    return {"message": "Welcome to PHC API"}
